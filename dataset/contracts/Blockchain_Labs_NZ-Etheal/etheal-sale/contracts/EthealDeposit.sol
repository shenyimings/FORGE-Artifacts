pragma solidity ^0.4.17;

import './SafeMath.sol';
import './Ownable.sol';
import './HasNoTokens.sol';
import './EthealWhitelist.sol';
import './iEthealSale.sol';

/**
 * @title EthealDeposit
 * @author thesved
 * @dev This contract is used for storing funds while doing Whitelist
 */
contract EthealDeposit is Ownable, HasNoTokens {
    using SafeMath for uint256;

    // storing deposits: make sure they fit in 2 x 32 byte
    struct Deposit {
        uint256 amount;         // 32 byte
        address beneficiary;    // 20 byte
        uint64 time;            // 8 byte
        bool cleared;           // 1 bit
    }
    uint256 public transactionCount;
    uint256 public pendingCount;
    mapping (uint256 => Deposit) public transactions;    // store transactions
    mapping (address => uint256[]) public addressTransactions;  // store transaction ids for addresses
    
    // sale contract to which we forward funds
    iEthealSale public sale;
    EthealWhitelist public whitelist;

    event Deposited(address indexed beneficiary, uint256 weiAmount);
    event Refunded(address indexed beneficiary, uint256 weiAmount, uint256 id);
    event Forwarded(address indexed beneficiary, uint256 weiAmount, uint256 id);

    ////////////////
    // Constructor
    ////////////////

    /// @notice Etheal deposit constructor
    /// @param _sale address of sale contract
    /// @param _whitelist address of whitelist contract
    function EthealDeposit(address _sale, address _whitelist) {
        require(_sale != address(0));
        sale = iEthealSale(_sale);
        whitelist = EthealWhitelist(_whitelist);
    }

    /// @notice Set sale contract address
    function setSale(address _sale) public onlyOwner {
        sale = iEthealSale(_sale);
    }

    /// @notice Set whitelist contract address
    function setWhitelist(address _whitelist) public onlyOwner {
        whitelist = EthealWhitelist(_whitelist);
    }

    /// @dev Override HasNoTokens#extractTokens to not be able to extract tokens until saleEnd and everyone got their funds back
    function extractTokens(address _token, address _claimer) public onlyOwner saleEnded {
        require(pendingCount == 0);

        super.extractTokens(_token, _claimer);
    }


    ////////////////
    // Deposit, forward, refund
    ////////////////

    modifier whitelistSet() {
        require(address(whitelist) != address(0));
        _;
    }

    modifier saleNotEnded() {
        require(address(sale) != address(0) && !sale.hasEnded());
        _;
    }

    modifier saleEnded() {
        require(address(sale) != address(0) && sale.hasEnded());
        _;
    }

    /// @notice payable fallback calls the deposit function
    function() public payable {
        deposit(msg.sender, "");
    }

    /// @notice depositing for investor, return transaction Id
    /// @param _investor address of investor
    /// @param _whitelistSign offchain whitelist signiture for address, optional
    function deposit(address _investor, bytes _whitelistSign) public payable whitelistSet saleNotEnded returns (uint256) {
        require(_investor != address(0));
        require(msg.value > 0);
        require(msg.value >= sale.minContribution());

        uint256 transactionId = addTransaction(_investor, msg.value);

        // forward transaction automatically if whitelist is okay, so the transaction doesnt revert
        if (whitelist.isWhitelisted(_investor) 
            || whitelist.isOffchainWhitelisted(_investor, _whitelistSign) 
            || sale.whitelistThreshold() >= sale.stakes(_investor).add(msg.value)
        ) {
            forwardTransactionInternal(transactionId, _whitelistSign);
        }

        return transactionId;
    }

    /// @notice forwarding a transaction
    function forwardTransaction(uint256 _id, bytes _whitelistSign) public whitelistSet saleNotEnded {
        require(forwardTransactionInternal(_id, _whitelistSign));
    }

    /// @notice forwarding multiple transactions: check whitelist
    function forwardManyTransaction(uint256[] _ids) public whitelistSet saleNotEnded {
        uint256 _threshold = sale.whitelistThreshold();

        for (uint256 i=0; i<_ids.length; i++) {
            // only forward if it is within threshold or whitelisted, so the transaction doesnt revert
            if ( whitelist.isWhitelisted(transactions[_ids[i]].beneficiary) 
                || _threshold >= sale.stakes(transactions[_ids[i]].beneficiary).add(transactions[_ids[i]].amount )
            ) {
                forwardTransactionInternal(_ids[i],"");
            }
        }
    }

    /// @notice forwarding transactions for an investor
    function forwardInvestorTransaction(address _investor, bytes _whitelistSign) public whitelistSet saleNotEnded {
        bool _whitelisted = whitelist.isWhitelisted(_investor) || whitelist.isOffchainWhitelisted(_investor, _whitelistSign);
        uint256 _amount = sale.stakes(_investor);
        uint256 _threshold = sale.whitelistThreshold();

        for (uint256 i=0; i<addressTransactions[_investor].length; i++) {
            _amount = _amount.add(transactions[ addressTransactions[_investor][i] ].amount);
            // only forward if it is within threshold or whitelisted, so the transaction doesnt revert
            if (_whitelisted || _threshold >= _amount) {
                forwardTransactionInternal(addressTransactions[_investor][i], _whitelistSign);
            }
        }
    }

    /// @notice refunding a transaction
    function refundTransaction(uint256 _id) public saleEnded {
        require(refundTransactionInternal(_id));
    }

    /// @notice refunding multiple transactions
    function refundManyTransaction(uint256[] _ids) public saleEnded {
        for (uint256 i=0; i<_ids.length; i++) {
            refundTransactionInternal(_ids[i]);
        }
    }

    /// @notice refunding an investor
    function refundInvestor(address _investor) public saleEnded {
        for (uint256 i=0; i<addressTransactions[_investor].length; i++) {
            refundTransactionInternal(addressTransactions[_investor][i]);
        }
    }


    ////////////////
    // Internal functions
    ////////////////

    /// @notice add transaction and returns its id
    function addTransaction(address _investor, uint256 _amount) internal returns (uint256) {
        uint256 transactionId = transactionCount;

        // save transaction
        transactions[transactionId] = Deposit({
            amount: _amount,
            beneficiary: _investor,
            time: uint64(now),
            cleared : false
        });

        // save transactionId for investor address
        addressTransactions[_investor].push(transactionId);

        transactionCount = transactionCount.add(1);
        pendingCount = pendingCount.add(1);
        Deposited(_investor,_amount);

        return transactionId;
    }

    /// @notice Forwarding a transaction, internal function, doesn't check sale status for speed up mass actions.
    /// @return whether forward was successful or not
    function forwardTransactionInternal(uint256 _id, bytes memory _whitelistSign) internal returns (bool) {
        require(_id < transactionCount);

        // if already cleared then return false
        if (transactions[_id].cleared) {
            return false;
        }

        // fixing bytes data to argument call data: data -> {data position}{data length}data
        bytes memory _whitelistCall = bytesToArgument(_whitelistSign, 96);

        // forwarding transaction to sale contract
        if (! sale.call.value(transactions[_id].amount)(bytes4(keccak256('depositEth(address,uint256,bytes)')), transactions[_id].beneficiary, uint256(transactions[_id].time), _whitelistCall) ) {
            return false;
        }
        transactions[_id].cleared = true;

        pendingCount = pendingCount.sub(1);
        Forwarded(transactions[_id].beneficiary, transactions[_id].amount, _id);

        return true;
    }

    /// @dev Fixing low level call for providing signature information: create proper padding for bytes information
    function bytesToArgument(bytes memory _sign, uint256 _position) internal pure returns (bytes memory c) {
        uint256 signLength = _sign.length;
        uint256 totalLength = signLength.add(64);
        uint256 loopMax = signLength.add(31).div(32);
        assembly {
            let m := mload(0x40)
            mstore(m, totalLength)          // store the total length
            mstore(add(m,32), _position)    // where does the data start
            mstore(add(m,64), signLength)   // store the length of signature
            for {  let i := 0 } lt(i, loopMax) { i := add(1, i) } { mstore(add(m, mul(32, add(3, i))), mload(add(_sign, mul(32, add(1, i))))) }
            mstore(0x40, add(m, add(32, totalLength)))
            c := m
        }
    }

    /// @notice Send back non-cleared transactions after sale is over, not checking status for speeding up mass actions
    function refundTransactionInternal(uint256 _id) internal returns (bool) {
        require(_id < transactionCount);

        // if already cleared then return false
        if (transactions[_id].cleared) {
            return false;
        }

        // sending back funds
        transactions[_id].cleared = true;
        transactions[_id].beneficiary.transfer(transactions[_id].amount);

        pendingCount = pendingCount.sub(1);
        Refunded(transactions[_id].beneficiary, transactions[_id].amount, _id);

        return true;
    }


    ////////////////
    // External functions
    ////////////////

    /// @notice gives back transaction ids based on filtering
    function getTransactionIds(uint256 from, uint256 to, bool _cleared, bool _nonCleared) view external returns (uint256[] ids) {
        uint256 i = 0;
        uint256 results = 0;
        uint256[] memory _ids = new uint256[](transactionCount);

        // search in contributors
        for (i = 0; i < transactionCount; i++) {
            if (_cleared && transactions[i].cleared || _nonCleared && !transactions[i].cleared) {
                _ids[results] = i;
                results++;
            }
        }

        ids = new uint256[](results);
        for (i = from; i <= to && i < results; i++) {
            ids[i] = _ids[i];
        }

        return ids;
    }
}