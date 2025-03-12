// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "asterizmprotocol/contracts/evm/AsterizmClient.sol";
import "./interfaces/IMultiChainToken.sol";

contract DeGuardNFT is ERC721, ERC721Enumerable, Ownable, Pausable, ERC721Burnable, ReentrancyGuard, IMultiChainToken, AsterizmClient {

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    /// Emits when currency rate updated
    event RateUpdated(uint value);

    /// Emits in 2 cases:
    /// 1 - Added new plan
    /// 2 - Updated existed plan
    event PlanUpdated(uint indexed index, uint price, uint range);
    event PlanRemoved(uint indexed index, uint price, uint range);
    event PlanSold(address user, uint plan);

    /// Multichain
    event EncodedPayloadRecieved(uint64 srcChainId, address srcAddress, uint nonce, uint _transactionId, bytes payload);
    event CrossChainTransferReceived(uint id, uint64 destChain, address from, address to, uint tokenId, uint _transactionId, address target);
    event CrossChainTransferCompleted(uint id, address to);

    /// Plan struct for NFT
    struct PurchasedPlan {
        uint startTime;
        uint endTime;
    }

    /// - `price` - price denominated in USD
    /// - `range` - represents date tange in days
    struct Plan {
        uint price;
        uint range;
        // string uri;
    }

    /// - `value` - currency rate
    /// - `updated` - timestamp
    struct Rate {
        uint value;
        uint updated;
    }

    struct CrossChainTransfer {
        bool exists;
        uint64 destChain;
        address from;
        address to;
        uint tokenId;
        address target;
    }

    uint private _days = 1 days;

    /// @dev Currency rate for networt native token
    /// TOKEN/USD where TOKEN is base currency, USD is qoute currency
    Rate public rate;

    Plan[] public plans;

    ///
    mapping(uint256 => PurchasedPlan) public tokenToPlan;

    mapping (uint => CrossChainTransfer) public crosschainTransfers;

    constructor(IInitializerSender _initializerLib)
    ERC721("DeGuardPlan", "DGP")
    AsterizmClient(_initializerLib, true, false)
    {
        rate = Rate(0, block.timestamp);
        /// For testing ONLY
        // safeMint(msg.sender, block.timestamp, block.timestamp + 30 days);
    }

    ///
    function safeMint(address to, uint _startTime, uint _endTime) internal {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        tokenToPlan[tokenId].startTime = _startTime;
        tokenToPlan[tokenId].endTime = _endTime;
        _safeMint(to, tokenId);
        // return tokenId;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// Plan tokens for wallet
    /// @param _owner address - user's address who holds NFTs plans
    /// @return array uint - contains start block, end block, time range in days
    function tokensOfOwner(address _owner) external view returns (uint[] memory) {
        uint tokenCount = balanceOf(_owner);
        uint[] memory tokensId = new uint256[](tokenCount);

        for (uint i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    /// Plan time range
    function getRange(address _owner, uint _id) external view returns (uint startTime, uint endTime, uint range) {
        uint256 tokenId = tokenOfOwnerByIndex(_owner, _id);
        require(_id == tokenId, "Token does not belong to user");
        PurchasedPlan memory plan = tokenToPlan[_id];
        return (plan.startTime, plan.endTime, (plan.endTime - plan.startTime) / 1 days);
    }

    /// Check current status of user plan
    /// @param _owner address - user's address (plan owner)
    /// @param _id uint - token index
    /// @return bool - validation for current timestamp
    function isValid(address _owner, uint _id) external view returns (bool) {
        uint256 tokenId = tokenOfOwnerByIndex(_owner, _id);
        require(_id == tokenId, "Token does not belong to user");
        PurchasedPlan memory plan = tokenToPlan[_id];
        return (plan.endTime >= block.timestamp);
    }

     /// For some cases when owner wants to stop plan selling
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /// @dev Updates currency rate
    /// @param _value TOKEN/USD where TOKEN is base currency, USD is qoute currency
    function updateRate(uint _value) public onlyOwner {
        require(_value > 0, "Currency rate must be higher than zero");
        rate.value = _value;
        rate.updated = block.timestamp;
        emit RateUpdated(rate.value);
    }

    /// Buy plan for service users
    /// @param _plan uint - plan id (index in array), starts from zero
    function buyPlan(uint _plan, uint64 _dstChainId, address _to) public payable nonReentrant whenNotPaused {
        address user = msg.sender;
        uint value = msg.value;
        require(rate.value > 0, "Currency rate must be higher than zero");
        require(_plan < plans.length, "Index is out of bounds");
        uint price = (rate.value * plans[_plan].price) / 10 ** 18;
        require(value == price, "Not enough money sent");
        uint _currentTime = block.timestamp;
        uint _endTime = _currentTime + plans[_plan].range;
        // uint tokenId = safeMint(user, _currentTime, _endTime);
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(user, tokenId);
        tokenToPlan[tokenId].startTime = _currentTime;
        tokenToPlan[tokenId].endTime = _endTime;
        crossChainTransfer(_dstChainId, user, _to, tokenId);
        emit PlanSold(user, _plan);
    }

    /// Add new plan to the factory's plans aray
    /// @param _priceInUSD uint256  - represents token price in USD with 18 decimals
    /// @param _daysRange uint256  - time range in days
    function addPlan(
        uint _priceInUSD,
        uint _daysRange
        // string memory uri
    ) public onlyOwner {
        plans.push(Plan(_priceInUSD, _daysRange * _days));

        emit PlanUpdated(plans.length - 1, _priceInUSD, _daysRange);
    }

    /// Remove plan from plans array
    /// @param index uint - plan id (index in array), starts from zero
    function removePlan(uint index) public onlyOwner {
        require(index < plans.length, "Index is out of bounds");

        Plan memory _plan = plans[index];

        for(uint i = index; i < plans.length - 1; i++){
            plans[i] = plans[i+1];      
        }
        plans.pop();

        emit PlanRemoved(plans.length + 1, _plan.price, _plan.range);
    }

    /// Get plan list with data readable range format
    /// @return array of Plan struct where range converted to days
    function getPlanList() public view returns (Plan[] memory) {
        Plan[] memory _plans = new Plan[](plans.length);
        for(uint i = 0; i < plans.length; i++){
            _plans[i] = Plan(plans[i].price, plans[i].range / _days);
        }
        return _plans;
    }

    /// Withdraw money from contract to the owner's wallet
    function withdraw() public onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }

    /// Cross-chain transfer
    /// @param _dstChainId uint64  Destination chain ID
    /// @param _from address  From address
    /// @param _to address  To address
    function crossChainTransfer(uint64 _dstChainId, address _from, address _to, uint _tokenId) public payable {
        // uint256 tokenId = tokenOfOwnerByIndex(_from, _tokenId);
        // require(_tokenId == tokenId, "Token does not belong to user");
        PurchasedPlan memory plan = tokenToPlan[_tokenId];
        _debitFrom(_from, _tokenId); // amount returned should not have dust
        _initAsterizmTransferEvent(_dstChainId, abi.encode(_to, _tokenId, _getTxId(), plan.startTime, plan.endTime));
    }

    /// Receive non-encoded payload
    /// @param _dto ClAsterizmReceiveRequestDto  Method DTO
    function _asterizmReceive(ClAsterizmReceiveRequestDto memory _dto) internal override {
        (address dstAddress, uint tokenId, , uint startTime, uint endTime) = abi.decode(_dto.payload, (address, uint, uint, uint, uint));
        safeMint(dstAddress, startTime, endTime);
        emit CrossChainTransferCompleted(tokenId, dstAddress);
    }

    /// Build packed payload (abi.encodePacked() result)
    /// @param _payload bytes  Default payload (abi.encode() result)
    /// @return bytes  Packed payload (abi.encodePacked() result)
    function _buildPackedPayload(bytes memory _payload) internal pure override returns(bytes memory) {
        (address dstAddress, uint tokenId, uint txId, uint startTime, uint endTime) = abi.decode(_payload, (address, uint, uint, uint, uint));
        
        return abi.encodePacked(dstAddress, tokenId, txId, startTime, endTime);
    }

    /// Debit logic
    /// @param _from address  From address
    /// @param _tokenId uint  Amount
    function _debitFrom(address _from, uint _tokenId) internal virtual {
        address spender = _msgSender();
        if (_from != spender) _isApprovedOrOwner(spender, _tokenId);
        burn(_tokenId);
    }

}