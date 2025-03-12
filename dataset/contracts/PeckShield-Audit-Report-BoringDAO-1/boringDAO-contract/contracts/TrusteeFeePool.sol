// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interface/ITrusteeFeePool.sol";

contract TrusteeFeePool is Ownable, ITrusteeFeePool{
    
    using SafeMath for uint256;
    
     uint256 public perTrustee;
     bytes32 public TRUSTEE_ROLE = "TRUSTEE_ROLE";

     mapping(address=>uint256) public userPerPaid;
     mapping(address=>uint256) public userReward;
     mapping(address=>uint256) public balanceOf;
     
     IERC20 public rewardToken;
     address public boringDAO;
     address public tunnel;
     
     constructor(address _rewardToken) public {
         rewardToken = IERC20(_rewardToken);
     }

     function trusteeCount() internal view returns(uint){
         return ITrusteeCount(boringDAO).getRoleMemberCount(TRUSTEE_ROLE);
     }
     
     function setBoringDAO(address _boringDAO) external onlyOwner {
         boringDAO = _boringDAO;
     }
     
     function setTunnel(address _tunnel) external onlyOwner {
         tunnel = _tunnel;
     }
     
     function notifyReward(uint reward) public override onlyTunnel {
         perTrustee = perTrustee.add(reward.div(trusteeCount()));
     }
     
     function earned(address account) public view returns (uint) {
         return perTrustee.sub(userPerPaid[account]).mul(balanceOf[account]).add(userReward[account]);
     }
     
     function claim() public updateReward(msg.sender){
         uint reward = userReward[msg.sender];
         userReward[msg.sender] = 0;
         rewardToken.transfer(msg.sender, reward);
     }
     
     function enter(address account) external override onlyBoringDAO updateReward(account){
         balanceOf[account] = 1;
         uint reward = userReward[msg.sender];
         userReward[msg.sender] = 0;
         rewardToken.transfer(msg.sender, reward);

     }
     
     function exit(address account) external override onlyBoringDAO updateReward(account) {
         balanceOf[account] = 0;
     }
     
     modifier updateReward(address account) {
         userReward[account] = earned(account);
         userPerPaid[account] = perTrustee;
         _;
     }
     
     modifier onlyBoringDAO {
         require(msg.sender == boringDAO, "TrusteePool::caller is not boringDAO");
         _;
     }
     
     modifier onlyTunnel {
         require(msg.sender == tunnel, "TrusteePool::caller is not tunnel");
         _;
     }
     
}

interface ITrusteeCount {
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}