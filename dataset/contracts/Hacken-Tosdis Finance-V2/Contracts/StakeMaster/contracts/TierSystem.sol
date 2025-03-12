pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/ITierSystem.sol";

contract TierSystem is ITierSystem, Ownable{
    using SafeMath for uint256;

    mapping(address => uint256) public usersBalance;

    event SetUserBalance(address account, uint256 balance);

    TierInfo public vipTier;
    TierInfo public holdersTier;
    TierInfo public publicTier;

    struct TierInfo {
        uint256 disAmount;     
        uint256 percent; 
    }

    constructor(
        uint256 _vipDisAmount, 
        uint256 _vipPercent, 
        uint256 _holdersDisAmount, 
        uint256 _holdersPercent, 
        uint256 _publicDisAmount, 
        uint256 _publicPercent
    ) public {
        setTier(_vipDisAmount, _vipPercent, _holdersDisAmount, _holdersPercent, _publicDisAmount, _publicPercent);
    }

    function setTier(uint256 _vipDisAmount, uint256 _vipPercent, 
                     uint256 _holdersDisAmount, uint256 _holdersPercent, 
                     uint256 _publicDisAmount, uint256 _publicPercent) public onlyOwner {
        vipTier.disAmount = _vipDisAmount;
        vipTier.percent = _vipPercent;

        holdersTier.disAmount = _holdersDisAmount;
        holdersTier.percent = _holdersPercent;

        publicTier.disAmount = _publicDisAmount;
        publicTier.percent = _publicPercent;
    }

    function addBalances(address[] memory _addresses, uint256[] memory _balances) external onlyOwner {
        for (uint i = 0; i < _addresses.length; i++) {
            usersBalance[_addresses[i]] = _balances[i];
            emit SetUserBalance(_addresses[i], _balances[i]);
        }
    }

     function getMaxEthPayment(address user, uint256 maxEthPayment)
        public
        view
        override
        returns (uint256)
    {
       uint256 _disBalance =  usersBalance[user];
        if(_disBalance>=vipTier.disAmount){
           return maxEthPayment.mul(vipTier.percent).div(100);
        }
        if(_disBalance>=holdersTier.disAmount){
           return maxEthPayment.mul(holdersTier.percent).div(100);
        }
        if(_disBalance>=publicTier.disAmount){
           return maxEthPayment.mul(publicTier.percent).div(100);
        }
        return 0;
    }
}