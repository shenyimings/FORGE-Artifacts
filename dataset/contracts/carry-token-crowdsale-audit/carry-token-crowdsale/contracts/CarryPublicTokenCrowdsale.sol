// The Carry token and the tokensale contracts
// Copyright (C) 2018 Carry Protocol
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./CarryToken.sol";

/**
 * @title CarryPublicTokenCrowdsale
 * @dev The Carry token public sale contract.
 */
contract CarryPublicTokenCrowdsale is CappedCrowdsale, Pausable {
    using SafeMath for uint256;

    uint256 constant maxGasPrice = 40000000000;  // 40 gwei

    // Individual min purchases.
    uint256 public individualMinPurchaseWei;

    struct IndividualMaxCap {
        uint256 timestamp;
        uint256 maxWei;
    }

    // Individual max purchases differ by time.  The mapping keys are timestamps
    // and values are weis an individual can purchase at most
    // If the transaction is made later than a timestamp it can accept
    // the corresponding cap at most.
    //
    // Where individualMaxCaps = [
    //   IndividualMaxCap(1533081600, 5 ether),
    //   IndividualMaxCap(1533686400, 10 ether)
    // ]
    // If a transaction is made before 1533081600 (2018-08-01 sharp UTC)
    // it disallows any purchase.
    // If a transaction is made between 1533081600 (2018-08-01 sharp UTC)
    // 1533686400 (2018-08-08 sharp UTC) it takes 5 ethers at most.
    // If a transaction is made after 1533686400 (2018-08-08 sharp UTC)
    // it takes 10 ethers at most.
    IndividualMaxCap[] public individualMaxCaps;

    mapping(address => uint256) public contributions;

    // Each index represents the grade (the order is arbitrary) and its value
    // represents a timestamp when people (i.e., addresses) belonging to that
    // grade becomes available to purchase tokens.  Note that the first value
    // (i.e., whitelistGrades[0]) must be zero since the index 0 must represent
    // the state of "not whitelisted."
    //
    // The index numbers are used by the whitelist mapping (see below).
    // As the key type of the whitelist mapping is uint8, there cannot be more
    // than 2^8 grades.
    uint256[] public whitelistGrades;

    // This mapping represents what grade each address belongs to.  Values are
    // an index number and refer to a grade (see the whitelistGrades array).
    // A special value 0 represents the predefined state that "it is not
    // whitelisted and does not belong to any grade."
    //
    // Where whitelistGrades = [0, 1533686400, 1533081600]
    //   and whitelist = [X => 2, Y => 1, Z => 0]
    //
    // X cannot purchase any tokens until 1533081600 (2018-08-01 sharp UTC),
    // but became to able to purchase tokens after that.
    // Y cannot purchase any tokens until 1533686400 (2018-08-08 sharp
    // UTC), but became to able to purchase tokens after that.
    // Z cannot purchase any tokens since it is not whitelisted and does not
    // belong to any grade.
    //
    // As values of a mapping in solidity are virtually all zeros by default,
    // addresses never associated by the whitelist mapping are not whitelisted
    // by default.
    mapping(address => uint8) public whitelist;

    // Token amounts people purchased.  Keys are an address and values are
    // CRE tokens (in minor units).  If X purchased 5 CRE it is represented as
    // [X => 5 * 10**18].
    mapping(address => uint256) public balances;

    // Whether to allow purchasers to withdraw their tokens.  Intended to be
    // false at first, and then become true at some point.
    bool public withdrawable;

    // The fixed due date (timestamp) of token delivery.  Even if withdrawable
    // if not set to true, since the due date purchasers become able to withdraw
    // tokens.  See also whenWithdrawable modifier below.
    uint256 public tokenDeliveryDue;

    mapping(address => uint256) public refundedDeposits;

    constructor(
        address _wallet,
        CarryToken _token,
        uint256 _rate,
        uint256 _cap,
        uint256 _tokenDeliveryDue,
        uint256[] _whitelistGrades,
        uint256 _individualMinPurchaseWei,

        // Since Solidity currently doesn't allows parameters to take array of
        // structs, we work around this by taking two arrays for each field
        // (timestmap and maxWei) separately.  It fails unless two arrays are
        // of equal length.
        uint256[] _individualMaxCapTimestamps,
        uint256[] _individualMaxCapWeis
    ) public CappedCrowdsale(_cap) Crowdsale(_rate, _wallet, _token) {
        require(
            _individualMaxCapTimestamps.length == _individualMaxCapWeis.length,
            "_individualMaxCap{Timestamps,Weis} do not have equal length."
        );
        tokenDeliveryDue = _tokenDeliveryDue;
        if (_whitelistGrades.length < 1) {
            whitelistGrades = [0];
        } else {
            require(
                _whitelistGrades.length < 0x100,
                "The grade number must be less than 2^8."
            );
            require(
                _whitelistGrades[0] == 0,
                "The _whitelistGrades[0] must be zero."
            );
            whitelistGrades = _whitelistGrades;
        }
        individualMinPurchaseWei = _individualMinPurchaseWei;
        for (uint i = 0; i < _individualMaxCapTimestamps.length; i++) {
            uint256 timestamp = _individualMaxCapTimestamps[i];
            require(
                i < 1 || timestamp > _individualMaxCapTimestamps[i - 1],
                "_individualMaxCapTimestamps have to be in ascending order and no duplications."
            );
            individualMaxCaps.push(
                IndividualMaxCap(
                    timestamp,
                    _individualMaxCapWeis[i]
                )
            );
        }
    }

    function _preValidatePurchase(
        address _beneficiary,
        uint256 _weiAmount
    ) internal whenNotPaused {
        // Prevent gas war among purchasers.
        require(
            tx.gasprice <= maxGasPrice,
            "Gas price is too expensive. Don't be competitive."
        );

        super._preValidatePurchase(_beneficiary, _weiAmount);

        uint8 grade = whitelist[_beneficiary];
        require(grade > 0, "Not whitelisted.");
        uint openingTime = whitelistGrades[grade];
        require(
            // solium-disable-next-line security/no-block-members
            block.timestamp >= openingTime,
            "Currently unavailable to purchase tokens."
        );

        uint256 contribution = contributions[_beneficiary];
        uint256 contributionAfterPurchase = contribution.add(_weiAmount);

        // If a contributor already has purchased a minimum amount, say 0.1 ETH,
        // then they can purchase once again with less than a minimum amount,
        // say 0.01 ETH, because they have already satisfied the minimum
        // purchase.
        require(
            contributionAfterPurchase >= individualMinPurchaseWei,
            "Sent ethers is not enough."
        );

        // See also the comment on the individualMaxCaps above.
        uint256 individualMaxWei = 0;
        for (uint i = 0; i < individualMaxCaps.length; i++) {
            uint256 capTimestamp = individualMaxCaps[i].timestamp;
            // solium-disable-next-line security/no-block-members
            if (capTimestamp <= block.timestamp) {
                individualMaxWei = individualMaxCaps[i].maxWei;
            } else {
                // Optimize gas consumption by trimming timestamps no more used.
                if (i > 1) {
                    uint offset = i - 1;
                    uint trimmedLength = individualMaxCaps.length - offset;
                    for (uint256 j = 0; j < trimmedLength; j++) {
                        individualMaxCaps[j] = individualMaxCaps[offset + j];
                    }
                    individualMaxCaps.length = trimmedLength;
                }
                break;
            }
        }
        require(
            contributionAfterPurchase <= individualMaxWei,
            individualMaxWei > 0
                ? "Total ethers you've purchased is too much."
                : "Purchase is currently disallowed."
        );
    }

    function _updatePurchasingState(
        address _beneficiary,
        uint256 _weiAmount
    ) internal {
        super._updatePurchasingState(_beneficiary, _weiAmount);
        contributions[_beneficiary] = contributions[_beneficiary].add(
            _weiAmount
        );
    }

    function addAddressesToWhitelist(
        address[] _beneficiaries,
        uint8 _grade
    ) external onlyOwner {
        require(_grade < whitelistGrades.length, "No such grade number.");
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            whitelist[_beneficiaries[i]] = _grade;
        }
    }

    // Override to prevent immediate delivery of tokens.
    function _processPurchase(
        address _beneficiary,
        uint256 _tokenAmount
    ) internal {
        balances[_beneficiary] = balances[_beneficiary].add(_tokenAmount);
    }

    function setWithdrawable(bool _withdrawable) external onlyOwner {
        withdrawable = _withdrawable;
    }

    modifier whenWithdrawable() {
        require(
            // solium-disable-next-line security/no-block-members
            withdrawable || block.timestamp >= tokenDeliveryDue,
            "Currently tokens cannot be withdrawn."
        );
        _;
    }

    event TokenDelivered(address indexed beneficiary, uint256 tokenAmount);

    function _deliverTokens(address _beneficiary) internal {
        uint256 amount = balances[_beneficiary];
        if (amount > 0) {
            balances[_beneficiary] = 0;
            _deliverTokens(_beneficiary, amount);
            emit TokenDelivered(_beneficiary, amount);
        }
    }

    function withdrawTokens() public whenWithdrawable {
        _deliverTokens(msg.sender);
    }

    function deliverTokens(
        address[] _beneficiaries
    ) public onlyOwner whenWithdrawable {
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            _deliverTokens(_beneficiaries[i]);
        }
    }

    event RefundDeposited(
        address indexed beneficiary,
        uint256 tokenAmount,
        uint256 weiAmount
    );
    event Refunded(
        address indexed beneficiary,
        address indexed receiver,
        uint256 weiAmount
    );

    /**
     * @dev Refund the given ether to a beneficiary.  It only can be called by
     * either the contract owner or the wallet (i.e., Crowdsale.wallet) address.
     * The only amount of the ether sent together in a transaction is refunded.
     */
    function depositRefund(address _beneficiary) public payable {
        require(
            msg.sender == owner || msg.sender == wallet,
            "No permission to access."
        );
        uint256 weiToRefund = msg.value;
        require(
            weiToRefund <= weiRaised,
            "Sent ethers is higher than even the total raised ethers."
        );
        uint256 tokensToRefund = _getTokenAmount(weiToRefund);
        uint256 tokenBalance = balances[_beneficiary];
        require(
            tokenBalance >= tokensToRefund,
            "Sent ethers is higher than the ethers _beneficiary has purchased."
        );
        weiRaised = weiRaised.sub(weiToRefund);
        balances[_beneficiary] = tokenBalance.sub(tokensToRefund);
        refundedDeposits[_beneficiary] = refundedDeposits[_beneficiary].add(
            weiToRefund
        );
        emit RefundDeposited(_beneficiary, tokensToRefund, weiToRefund);
    }

    /**
     * @dev Receive one's refunded ethers in the deposit.  It can be called by
     * only a beneficiary of refunds.
     * It takes a parameter, a wallet address to receive the deposited
     * (refunded) ethers.  (Usually it would be the same to the beneficiary
     * address unless the beneficiary address is a smart contract unable to
     * receive ethers.)
     */
    function receiveRefund(address _wallet) public {
        _transferRefund(msg.sender, _wallet);
    }

    function _transferRefund(address _beneficiary, address _wallet) internal {
        uint256 depositedWeiAmount = refundedDeposits[_beneficiary];
        require(depositedWeiAmount > 0, "_beneficiary has never purchased.");
        refundedDeposits[_beneficiary] = 0;
        contributions[_beneficiary] = contributions[_beneficiary].sub(
            depositedWeiAmount
        );
        _wallet.transfer(depositedWeiAmount);
        emit Refunded(_beneficiary, _wallet, depositedWeiAmount);
    }
}
