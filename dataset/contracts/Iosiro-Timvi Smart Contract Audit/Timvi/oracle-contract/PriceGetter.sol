pragma solidity 0.5.11;

import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

contract Ownable {
    address public owner;
    address public pendingOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Modifier throws if called by any account other than the pendingOwner.
     */
    modifier onlyPendingOwner() {
        require(msg.sender == pendingOwner);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    /**
     * @dev Allows the current owner to set the pendingOwner address.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) onlyOwner public {
        pendingOwner = newOwner;
    }

    /**
     * @dev Allows the pendingOwner address to finalize the transfer.
     */
    function claimOwnership() onlyPendingOwner public {
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

}


contract PriceGetter is usingOraclize, Ownable {

    event PriceUpdated(uint256 ethUsdPrice);
    event LogNewOraclizeQuery(string description);
    event Withdraw(address to, uint amount);

    uint public price;
    string public IPFSHash = "QmVXihTAKo3mwEHBMeM4EDG8MbWHFTvxoigdFAgmTneWra";
    uint public lastCallbackTimestamp;
    uint public oraclize_timeout = 1800; // 30 min in sec
    uint public oraclize_callback_gas_limit = 150000;
    uint public minTimeUpdate = 1500; // 25 min in sec

    uint public expirationTime = 7200;

    constructor() public payable {
        oraclize_setProof(proofStorage_IPFS);
        price = 17888333; // init val to get cheaper rewriting on callback
        update(0);
        oraclize_setCustomGasPrice(13800000000);
    }

    function () external payable {}

    function __callback(bytes32 myid, string memory result, bytes memory proof) public {
        require(msg.sender == oraclize_cbAddress());
        require(now > lastCallbackTimestamp + minTimeUpdate);
        uint _price = parseInt(result, 5);
        if (_price != 0) {
            price = _price;
            lastCallbackTimestamp = now;
            emit PriceUpdated(price);
        }
        request(oraclize_timeout);
    }

    function update(uint _timeout) public payable {
        require(msg.sender == address(owner));
        request(_timeout);
    }

    function request(uint _timeout) internal {
        if (oraclize_getPrice("computation") > address(this).balance) {
            emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
            oraclize_query(_timeout, "computation", IPFSHash, oraclize_callback_gas_limit);
        }
    }

    function setGasPrice(uint256 _gasPrice) external onlyOwner {
        oraclize_setCustomGasPrice(_gasPrice);
    }

    function setOraclizeCallbackGasLimit(uint _limit) public onlyOwner {
        oraclize_callback_gas_limit = _limit;
    }

    function setOraclizeTimeout(uint _timeout) public onlyOwner {
        oraclize_timeout = _timeout;
    }

    function ethUsdPrice() public view returns (uint) {
        require(now - lastCallbackTimestamp < expirationTime);
        return price;
    }

    function setIPFSHash(string memory _hash) public onlyOwner {
        IPFSHash = _hash;
    }

    function withdraw(address payable _to, uint _amount) public onlyOwner {
        address(_to).transfer(_amount);
        emit Withdraw(_to, _amount);
    }

    function setPrice_TESTNET_ONLY(uint256 _price) public onlyOwner {
        price = _price;
        lastCallbackTimestamp = now;
        emit PriceUpdated(price);
    }

    function setExpirationPeriod(uint _period) public onlyOwner {
        expirationTime = _period;
    }
}
