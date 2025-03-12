pragma solidity 0.5.10;

import {BytesLib} from "@summa-tx/bitcoin-spv-sol/contracts/BytesLib.sol";
import {BTCUtils} from "@summa-tx/bitcoin-spv-sol/contracts/BTCUtils.sol";

import './Loans.sol';
import './P2WSHInterface.sol';
import './ISPVRequestManager.sol';
import './DSMath.sol';

/**
 * @title Atomic Loans Collateral Contract
 * @author Atomic Loans
 */
contract Collateral is DSMath {
    P2WSHInterface p2wsh;
    Loans loans;
    ISPVRequestManager public onDemandSpv;

    uint256 public constant ADD_COLLATERAL_EXPIRY = 4 hours;

    mapping (bytes32 => CollateralDetails)   public collaterals;
    mapping (bytes32 => LoanRequests)        public loanRequests;
    mapping (uint256 => RequestDetails)      public requestsDetails;
    mapping (uint256 => uint256)             public finalRequestToInitialRequest;

    mapping (bytes32 => CollateralDetails)                     public temporaryCollaterals;
    mapping (bytes32 => mapping(uint256 => CollateralDeposit)) public collateralDeposits;
    mapping (bytes32 => uint256)                               public collateralDepositIndex;
    mapping (bytes32 => uint256)                               public collateralDepositFinalizedIndex;

    mapping (bytes32 => mapping(uint8 => uint256))             public txidToOutputIndexToCollateralDepositIndex;
    mapping (bytes32 => mapping(uint8 => bool))                public txidToOutputToRequestValid;

    address deployer;

    /**
     * @notice Container for the current collateral info
     * @member refundableCollateral Amount of refundable collateral in sats
     * @member seizableCollateral Amount of seizable collateral in sats
     * @member unaccountedRefundableCollateral Amount of unnacounted refundable collateral in sats (used when minSeizableCollateral is not met)
     */
    struct CollateralDetails {
        uint256 refundableCollateral;
        uint256 seizableCollateral;
        uint256 unaccountedRefundableCollateral; // RefundableCollateral that's not accounted for since minSeizableCollateral is not satisfied
    }

    /**
     * @notice Container for a collateral deposit from spv relay
     * @member amount Amount of collateral to deposited in sats
     * @member finalized Indicates whether the collateral deposit proof has 6 confirmations
     * @member seizable Indicates whether the collateral deposit is seizable
     * @member expiry Timestamp when collateral deposit is no longer valid (4 hours since 6 confirmations should be received by then)
     */
    struct CollateralDeposit {
        uint256 amount;
        bool    finalized; // 6 confirmations
        bool    seizable;
        uint256 expiry;
    }

    /**
     * @notice Container for a spv relay request
     * @member loan The Id of a Loan
     * @member finalized Indicates whether the collateral request is for a proof with 6 confirmations
     * @member seizable Indicates whether the collateral request is for a proof with seizable collateral
     * @member p2wshAddress P2WSH Address of the collateral request
     */
    struct RequestDetails {
        bytes32 loan;
        bool    finalized;
        bool    seizable;
        bytes32 p2wshAddress;
    }

    /**
     * @notice Container for a spv relay requests
     * @member refundRequestIDOneConf Request ID for Refundable Collateral Proof with One Confirmation
     * @member refundRequestIDSixConf Request ID for Refundable Collateral Proof with Six Confirmations
     * @member seizeRequestIDOneConf Request ID for Seizable Collateral Proof with One Confirmation
     * @member seizeRequestIDSixConf Request ID for Seizable Collateral Proof with Six Confirmations
     */
    struct LoanRequests {
        uint256 refundRequestIDOneConf;
        uint256 refundRequestIDSixConf;
        uint256 seizeRequestIDOneConf;
        uint256 seizeRequestIDSixConf;
    }

    event Spv(bytes32 _txid, bytes _vout, uint256 _requestID, uint8 _outputIndex);

    event RequestSpv(bytes32 loan);

    event CancelSpv(bytes32 loan);

    /**
     * @notice Get the Collateral of a Loan
     * @param loan The Id of a Loan
     * @return Amount of collateral backing the loan (in sats)
     */
    function collateral(bytes32 loan) public view returns (uint256) {
        // if the number of 6 conf txs spv proofs != the number of 1 conf txs spv proofs (this means temporary collateral is relevant) and
        // all seizable collateral is >= minSeizableCollateral (make sure seizableCollateral is satisfied before refundableCollateral) and
        // current time < 4 hour expiry on latest 1 conf tx spv proof (make sure reorg isn't occuring)
        // then return all collateral including refundableCollateral, seizableCollateral, temporaryRefundableCollateral, temporarySeizableCollateral
        // otherwise, only return refundable and seizable collateral
        if (collateralDepositIndex[loan] != collateralDepositFinalizedIndex[loan] &&
            add(collaterals[loan].seizableCollateral, temporaryCollaterals[loan].seizableCollateral) >= loans.minSeizableCollateral(loan) &&
            now < collateralDeposits[loan][collateralDepositFinalizedIndex[loan]].expiry) {
            return add(add(refundableCollateral(loan), seizableCollateral(loan)), add(temporaryCollaterals[loan].refundableCollateral, temporaryCollaterals[loan].seizableCollateral));
        } else {
            return add(refundableCollateral(loan), seizableCollateral(loan));
        }
    }

    /**
     * @notice Get the Refundable Collateral of a Loan
     * @param loan The Id of a Loan
     * @return Amount of refundable collateral backing the loan (in sats)
     */
    function refundableCollateral(bytes32 loan) public view returns (uint256) {
        return collaterals[loan].refundableCollateral;
    }

    /**
     * @notice Get the Seizable Collateral of a Loan
     * @param loan The Id of a Loan
     * @return Amount of seizable collateral backing the loan (in sats)
     */
    function seizableCollateral(bytes32 loan) public view returns (uint256) {
        return collaterals[loan].seizableCollateral;
    }

    /**
     * @notice Get the Temporary Refundable Collateral of a Loan
     * @dev Represents the amount of refundable collateral that has been locked and only has 1 confirmation, where 6 confirmations hasn't been received yet
     * @param loan The Id of a Loan
     * @return Amount of temporary refundable collateral backing the loan (in sats)
     */
    function temporaryRefundableCollateral(bytes32 loan) external view returns (uint256) {
        return temporaryCollaterals[loan].refundableCollateral;
    }

    /**
     * @notice Get the Temporary Seizable Collateral of a Loan
     * @dev Represents the amount of seizable collateral that has been locked and only has 1 confirmation, where 6 confirmations hasn't been received yet
     * @param loan The Id of a Loan
     * @return Amount of temporary seizable collateral backing the loan (in sats)
     */
    function temporarySeizableCollateral(bytes32 loan) external view returns (uint256) {
        return temporaryCollaterals[loan].seizableCollateral;
    }

    /**
     * @notice Construct a new Collateral contract
     * @param loans_ The address of the Loans contract
     */
    constructor (Loans loans_) public {
        require(address(loans_) != address(0), "Loans address must be non-zero");

        loans = loans_;
        deployer = msg.sender;
    }

    /**
     * @notice Sets P2WSH contract
     * @param p2wsh_ Address of P2WSH contract
     */
    function setP2WSH(P2WSHInterface p2wsh_) external {
        require(msg.sender == deployer, "Loans.setP2WSH: Only the deployer can perform this");
        require(address(p2wsh) == address(0), "Loans.setP2WSH: The P2WSH address has already been set");
        require(address(p2wsh_) != address(0), "Loans.setP2WSH: P2WSH address must be non-zero");
        p2wsh = p2wsh_;
    }

    /**
     * @notice Sets OnDemandSpv contract address
     * @param onDemandSpv_ Address of OnDemandSpv contract
     */
    function setOnDemandSpv(ISPVRequestManager onDemandSpv_) external {
        require(msg.sender == deployer, "Loans.setOnDemandSpv: Only the deployer can perform this");
        require(address(onDemandSpv) == address(0), "Loans.setOnDemandSpv: The OnDemandSpv address has already been set");
        require(address(onDemandSpv_) != address(0), "Loans.setOnDemandSpv: OnDemandSpv address must be non-zero");
        onDemandSpv = onDemandSpv_;
    }

    /**
     * @notice Unset OnDemandSpv contract address
     */
    function unsetOnDemandSpv() external {
        require(msg.sender == deployer, "Loans.setOnDemandSpv: Only the deployer can perform this");
        require(address(onDemandSpv) != address(0), "Loans.setOnDemandSpv: The OnDemandSpv address has not been set");
        onDemandSpv = ISPVRequestManager(address(0));
    }

    /**
     * @notice Sets current Collateral Amount for a Loan
     * @param loan ID for a Loan
     * @param refundableCollateral_ Amount of refundable collateral to update in sats
     * @param seizableCollateral_ Amount of seizable collateral to update in sats
     */
    function setCollateral(bytes32 loan, uint256 refundableCollateral_, uint256 seizableCollateral_) external {
        require(msg.sender == address(loans), "Loans.setCollateral: Only the loans contract can perform this");

        collaterals[loan].refundableCollateral = refundableCollateral_;
        collaterals[loan].seizableCollateral = seizableCollateral_;
    }

    /**
     * @notice Consumer for Bitcoin transaction information
     * @dev Handles Bitcoin events that have been validated by the Relay contract (onDemandSpv by Summa)
     * @param _vout        The length-prefixed output vector of the bitcoin tx that triggered the notification.
     * @param _requestID   The ID of the event request that this notification satisfies. The ID is returned by
     *                     OnDemandSPV.request and should be locally stored by
     *                     any contract that makes more than one request.
     * @param _outputIndex The index of the output in the _vout that triggered
     *                     the notification. Useful for subscribing to transactions
     *                     that spend the newly-created UTXO.
     */
    function spv(bytes32 _txid, bytes calldata, bytes calldata _vout, uint256 _requestID, uint8, uint8 _outputIndex) external {
        require(msg.sender == address(onDemandSpv), "Collateral.spv: Only the onDemandSpv can perform this");

        require(_txid != bytes32(0), "Collateral.spv: txid should be non-zero");
        require(BytesLib.toBytes32(_vout) != bytes32(0), "Collateral.spv: vout should be non-zero");

        bytes memory outputAtIndex = BTCUtils.extractOutputAtIndex(_vout, _outputIndex);
        uint256 amount = uint(BTCUtils.extractValue(outputAtIndex));

        bytes32 loan = requestsDetails[_requestID].loan;

        require(
            BytesLib.toBytes32(BTCUtils.extractHash(outputAtIndex)) == requestsDetails[_requestID].p2wshAddress,
            "Collateral.spv: Incorrect P2WSH address"
        );

        // Check if spv proof is for 6 confirmations (refundRequestIDSixConf or seizeRequestIDSixConf)
        if (requestsDetails[_requestID].finalized) {
            // Check that proof for 1 confirmation (refundRequestIDOneConf or seizeRequestIDOneConf) for this specific utxo has already been processed
            if (txidToOutputToRequestValid[_txid][_outputIndex]) {
                // Check if spv proof is seizable collateral (seizeRequestIDSixConf)
                if (requestsDetails[_requestID].seizable) {
                    // Add amount to Seizable Collateral
                    collaterals[loan].seizableCollateral = add(collaterals[loan].seizableCollateral, amount);

                    // Subtract amount from Temporary Seizable Collateral
                    temporaryCollaterals[loan].seizableCollateral = sub(temporaryCollaterals[loan].seizableCollateral, amount);
                } else {
                    // Add amount to Refundable Collateral if minSeizableCollateral is satisfied, else add to unaccountedRefundableCollateral
                    if (collaterals[loan].seizableCollateral >= loans.minSeizableCollateral(loan)) {
                        collaterals[loan].refundableCollateral = add(collaterals[loan].refundableCollateral, amount);
                    } else {
                        collaterals[loan].unaccountedRefundableCollateral = add(collaterals[loan].unaccountedRefundableCollateral, amount);
                    }

                    // Subtract amount from Temporary Refundable Collateral
                    temporaryCollaterals[loan].refundableCollateral = sub(temporaryCollaterals[loan].refundableCollateral, amount);
                }

                // Indicate that spv proof has received 6 confirmations
                collateralDeposits[loan][txidToOutputIndexToCollateralDepositIndex[_txid][_outputIndex]].finalized = true;

                _updateCollateralDepositFinalizedIndex(loan);
            }
            // In the case that proof for 6 confirmations comes before proof for 1 confirmation
            else {
                // Ensure amount is greater than 1% of collateral value
                if (amount >= div(collateral(loan), 100)) {
                    // Indicate that spv proof for 1 confirmation is no longer needed for this specific request
                    txidToOutputToRequestValid[_txid][_outputIndex] = true;

                    _setCollateralDeposit(loan, collateralDepositIndex[loan], amount, requestsDetails[_requestID].seizable);
                    collateralDeposits[loan][collateralDepositIndex[loan]].finalized = true;
                    txidToOutputIndexToCollateralDepositIndex[_txid][_outputIndex] = collateralDepositIndex[loan];
                    collateralDepositIndex[loan] = add(collateralDepositIndex[loan], 1);

                    // Check if spv proof is seizable collateral (seizeRequestIDSixConf)
                    if (requestsDetails[_requestID].seizable) {
                        // Add amount to Seizable Collateral
                        collaterals[loan].seizableCollateral = add(collaterals[loan].seizableCollateral, amount);
                    } else {
                        // Add amount to Refundable Collateral
                        collaterals[loan].refundableCollateral = add(collaterals[loan].refundableCollateral, amount);
                    }

                    _updateExistingRefundableCollateral(loan);
                    _updateCollateralDepositFinalizedIndex(loan);
                }
            }
        }
        // Check if spv proof is for 1 confirmation (refundRequestIDOneConf or seizeRequestIDOneConf)
        else {
            // Ensure amount is greater than 1% of collateral value
            if (amount >= div(collateral(loan), 100) && !txidToOutputToRequestValid[_txid][_outputIndex]) {
                // Indicate that spv proof for 1 confirmation has been received for this specific request
                txidToOutputToRequestValid[_txid][_outputIndex] = true;

                _setCollateralDeposit(loan, collateralDepositIndex[loan], amount, requestsDetails[_requestID].seizable);
                txidToOutputIndexToCollateralDepositIndex[_txid][_outputIndex] = collateralDepositIndex[loan];
                collateralDepositIndex[loan] = add(collateralDepositIndex[loan], 1);

                // Check if spv proof is seizable collateral (seizeRequestIDSixConf)
                if (requestsDetails[_requestID].seizable) {
                    // Add amount to Temporary Seizable Collateral
                    temporaryCollaterals[loan].seizableCollateral = add(temporaryCollaterals[loan].seizableCollateral, amount);
                } else {
                    // Add amount to Temporary Refundable Collateral
                    temporaryCollaterals[loan].refundableCollateral = add(temporaryCollaterals[loan].refundableCollateral, amount);
                }

                _updateExistingRefundableCollateral(loan);
            }
        }

        emit Spv(_txid, _vout, _requestID, _outputIndex);
    }

    function _setCollateralDeposit (bytes32 loan, uint256 collateralDepositIndex_, uint256 amount_, bool seizable_) private {
        collateralDeposits[loan][collateralDepositIndex_].amount = amount_;
        collateralDeposits[loan][collateralDepositIndex_].seizable = seizable_;
        collateralDeposits[loan][collateralDepositIndex_].expiry = now + ADD_COLLATERAL_EXPIRY;
    }

    function _updateExistingRefundableCollateral (bytes32 loan) private {
        if (add(collaterals[loan].seizableCollateral, temporaryCollaterals[loan].seizableCollateral) >= loans.minSeizableCollateral(loan) &&
            collaterals[loan].unaccountedRefundableCollateral != 0) {
            collaterals[loan].refundableCollateral = add(collaterals[loan].refundableCollateral, collaterals[loan].unaccountedRefundableCollateral);
            collaterals[loan].unaccountedRefundableCollateral = 0;
        }
    }

    function _updateCollateralDepositFinalizedIndex (bytes32 loan) private {
        // check if collateralDepositFinalizedIndex should be increased
        for (uint i = collateralDepositFinalizedIndex[loan]; i <= collateralDepositIndex[loan]; i++) {
            if (collateralDeposits[loan][i].finalized == true) {
                collateralDepositFinalizedIndex[loan] = add(collateralDepositFinalizedIndex[loan], 1);
            } else {
                break;
            }
        }
    }

    /**
     * @notice Creates request for Spv Relay
     * @param loan ID for a Loan
     */
    function requestSpv(bytes32 loan) external {
        require(msg.sender == address(loans), "Collateral.requestSpv: Only the loans contract can perform this");

        (, bytes32 refundableP2WSH) = p2wsh.getP2WSH(loan, false); // refundable collateral
        (, bytes32 seizableP2WSH) = p2wsh.getP2WSH(loan, true); // seizable collateral

        uint256 onePercentOfCollateral = div(collateral(loan), 100);

        uint256 refundRequestIDOneConf = onDemandSpv
            .request(hex"", abi.encodePacked(hex"220020", refundableP2WSH), uint64(onePercentOfCollateral), address(this), 1);
        uint256 refundRequestIDSixConf = onDemandSpv
            .request(hex"", abi.encodePacked(hex"220020", refundableP2WSH), uint64(onePercentOfCollateral), address(this), 6);

        uint256 seizeRequestIDOneConf = onDemandSpv
            .request(hex"", abi.encodePacked(hex"220020", seizableP2WSH), uint64(onePercentOfCollateral), address(this), 1);
        uint256 seizeRequestIDSixConf = onDemandSpv
            .request(hex"", abi.encodePacked(hex"220020", seizableP2WSH), uint64(onePercentOfCollateral), address(this), 6);

        loanRequests[loan].refundRequestIDOneConf = refundRequestIDOneConf;
        loanRequests[loan].refundRequestIDSixConf = refundRequestIDSixConf;
        loanRequests[loan].seizeRequestIDOneConf = seizeRequestIDOneConf;
        loanRequests[loan].seizeRequestIDSixConf = seizeRequestIDSixConf;

        requestsDetails[refundRequestIDOneConf].loan = loan;
        requestsDetails[refundRequestIDOneConf].p2wshAddress = refundableP2WSH;

        requestsDetails[refundRequestIDSixConf].loan = loan;
        requestsDetails[refundRequestIDSixConf].finalized = true;
        requestsDetails[refundRequestIDSixConf].p2wshAddress = refundableP2WSH;

        finalRequestToInitialRequest[refundRequestIDSixConf] = refundRequestIDOneConf;

        requestsDetails[seizeRequestIDOneConf].loan = loan;
        requestsDetails[seizeRequestIDOneConf].seizable = true;
        requestsDetails[seizeRequestIDOneConf].p2wshAddress = seizableP2WSH;

        requestsDetails[seizeRequestIDSixConf].loan = loan;
        requestsDetails[seizeRequestIDSixConf].seizable = true;
        requestsDetails[seizeRequestIDSixConf].finalized = true;
        requestsDetails[seizeRequestIDSixConf].p2wshAddress = seizableP2WSH;

        finalRequestToInitialRequest[seizeRequestIDSixConf] = seizeRequestIDOneConf;

        emit RequestSpv(loan);
    }

    /**
     * @notice Cancels request for Spv Relay
     * @param loan ID for a Loan
     */
    function cancelSpv(bytes32 loan) external {
        require(msg.sender == address(loans), "Collateral.cancelSpv: Only the loans contract can perform this");

        require(onDemandSpv.cancelRequest(loanRequests[loan].refundRequestIDOneConf), "Collateral.cancelSpv: refundRequestIDOneConf failed");
        require(onDemandSpv.cancelRequest(loanRequests[loan].refundRequestIDSixConf), "Collateral.cancelSpv: refundRequestIDSixConf failed");
        require(onDemandSpv.cancelRequest(loanRequests[loan].seizeRequestIDOneConf), "Collateral.cancelSpv: seizeRequestIDOneConf failed");
        require(onDemandSpv.cancelRequest(loanRequests[loan].seizeRequestIDSixConf), "Collateral.cancelSpv: seizeRequestIDSixConf failed");

        emit CancelSpv(loan);
    }
}
