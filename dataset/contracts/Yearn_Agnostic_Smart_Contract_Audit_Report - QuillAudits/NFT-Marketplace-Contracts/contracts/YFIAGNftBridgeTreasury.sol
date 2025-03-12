//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IYFIAGNftMarketplace.sol";
contract YFIAGNftBridgeTreasury is Ownable, ReentrancyGuard{
    struct Item{
        uint256 tokenId;
        uint256 price;
        uint256 amount;
        string fromChain;
        string toChain;
        address issuer;
    }
    
    mapping (uint256=>Item) public queues;
    IYFIAGNftMarketplace public market;
    constructor(address _market){
        market = IYFIAGNftMarketplace(_market);
    }
    function pay(uint256 tokenId,uint256 _price, uint256 amount, string memory fromChain, string memory toChain) public payable {
        require(msg.value >= amount, "Bad amount");
        Item storage item = queues[tokenId];
        item.amount = amount;
        item.price = _price;
        item.fromChain = fromChain;
        item.toChain = toChain;
        item.issuer = msg.sender;
    }
    function withdraw() external nonReentrant onlyOwner {
        payable(address(msg.sender)).transfer(getBalance());
    }
    function refund(address _target, uint256 _amount) external nonReentrant onlyOwner {
        require(getBalance() >= _amount,"Bad balance");
        payable(address(_target)).transfer(_amount);
    }
    function withdraw(address token) external nonReentrant onlyOwner {
        IERC20(token).transfer(msg.sender,IERC20(token).balanceOf(address(this)));
    }
    function getBalance() public view returns(uint256){
        address _self = address(this);
        uint256 _balance = _self.balance;
        return _balance;
    }
    function setMarketplaceAddress(address marketPlaceAddress) external onlyOwner() {
        market = IYFIAGNftMarketplace(marketPlaceAddress);
    }
    
}