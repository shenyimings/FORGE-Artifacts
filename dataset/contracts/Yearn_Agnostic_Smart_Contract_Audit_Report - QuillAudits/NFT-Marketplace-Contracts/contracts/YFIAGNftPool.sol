//SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <=0.8.6;

import "./utils/Address.sol";
import "./utils/SafeMath.sol";
import "./interfaces/IYFIAGNftMarketplace.sol";
import "./interfaces/IERC20.sol";
import "./utils/Ownable.sol";
import "./interfaces/IYFIAGNftPool.sol";
import "./utils/ReentrancyGuard.sol";

contract YFIAGNftPool is IYFIAGNftPool, Ownable, ReentrancyGuard{
    IYFIAGNftMarketplace public YFIAGMKT;
    using Address for address;
    using SafeMath for uint256;

    mapping(address => mapping(address => uint256)) amountWithdrawn;

    constructor(address _YFIAGNftMarketplace, address _owner) {
        YFIAGMKT = IYFIAGNftMarketplace(_YFIAGNftMarketplace);
        transferOwnership(_owner);
    }

    function getBalance() public view override returns(uint256) {
        address _self = address(this);
        uint256 _balance = _self.balance;
        return _balance;
    }

    function getAmountEarn(address _user, address _tokenAddress) public view override returns(uint256){
        return YFIAGMKT.getAmountEarn(_user, _tokenAddress);
    }

    function getAmountWithdrawn(address _user, address _tokenAddress) public view override returns(uint256){
        return amountWithdrawn[_user][_tokenAddress];
    }

    function withdraw(address _tokenAddress) external override nonReentrant {
        uint256 subOwnerFee = YFIAGMKT.getAmountEarn(msg.sender, _tokenAddress);
        if(_tokenAddress == address(0)){
            require(subOwnerFee > 0, "Earn = 0");
            require(address(this).balance >= subOwnerFee, "Balance invalid");
            payable(msg.sender).transfer(subOwnerFee);
            amountWithdrawn[msg.sender][_tokenAddress] += subOwnerFee;
            YFIAGMKT.setDefaultAmountEarn(msg.sender, _tokenAddress);
        }else{
            require(subOwnerFee > 0, "Earn = 0");
            require(IERC20(_tokenAddress).balanceOf(address(this)) >= subOwnerFee, "Balance invalid");
            IERC20(_tokenAddress).transferFrom(address(this), msg.sender, subOwnerFee);
            amountWithdrawn[msg.sender][_tokenAddress] += subOwnerFee;
            YFIAGMKT.setDefaultAmountEarn(msg.sender, _tokenAddress);
        }
    }

    function subOwnerFeeBalance() public payable override{
    }

    function withdrawAdmin(address _tokenAddress) external override onlyOwner() nonReentrant {
        if(_tokenAddress == address(0)){
            payable(owner()).transfer(getBalance());
        }else{
            uint256 amount = IERC20(_tokenAddress).balanceOf(address(this));
            IERC20(_tokenAddress).transferFrom(address(this), msg.sender, amount);
        }
    }

    function setMarketplaceAddress(address marketPlaceAddress) external override onlyOwner() {
        YFIAGMKT = IYFIAGNftMarketplace(marketPlaceAddress);
    }

}