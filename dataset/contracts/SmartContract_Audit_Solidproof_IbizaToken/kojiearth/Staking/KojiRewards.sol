// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function safeTransferFrom(address from, address to, uint256 value) external;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IAuth {
    function isAuthorized(address _address) external view returns (bool);
    function getKojiFlux() external view returns (address);
    function getKojiStaking() external view returns (address);
    function getKojiEarth() external view returns (address);
}

interface IKojiStaking {
    function redeemTotalRewards(address _user) external;
    function setKojiFluxBalance(address _address, uint256 _amount) external;
    function getKojiFluxBalance(address _address) external view returns (uint256);
}

contract KojiRewards is Ownable, ReentrancyGuard {

    using SafeMath for uint256;

    modifier onlyAuthorized() {
        require(auth.isAuthorized(_msgSender()) || owner() == address(_msgSender()), "User not Authorized to Rewards Contract");
        _;
    }

    IBEP20 internal kojifluxInterface;
    IBEP20 internal tokencontractv2Interface;
    IBEP20 internal rewardtoken;

    //IKojiStaking public staking;
    //address private stakingContract; 

    mapping (address => uint256) public holderRealized;
    mapping (address => uint256) public holderRewardLast;
    mapping (address => bool) public blacklisted;
    
    bool public rewardsEnabled = true;
    bool public enableKojiWithdraw = false; // Whether KOJIF is withdrawable from this contract (default false).
    bool public enableFluxWithdraw = false; // Whether FLUX is withdrawable from this contract (default false).

    IAuth private auth;

    event Withdraw(address indexed user, uint256 amount);
    
    constructor(address _auth) {
        auth = IAuth(_auth);
    }

    receive() external payable {}

    // This will allow to rescue ETH sent to the contract
    function rescueETHFromContract() external onlyAuthorized {
        address payable _owner = payable(_msgSender());
        _owner.transfer(address(this).balance);
    }

    // Function to allow admin to claim *other* ERC20 tokens sent to this contract
    function transferERC20Tokens(address _tokenAddr, address _to, uint _amount) public onlyAuthorized {
        IBEP20(_tokenAddr).transfer(_to, _amount);
    }

    function payPendingRewards(address _holder, uint256 _amount) external {
        require(_msgSender() == address(auth.getKojiStaking()), "Rewards are not payable outside of the staking contract");
        require(enableKojiWithdraw, "KOJI withdrawals are not enabled");

        holderRealized[_holder] = holderRealized[_holder].add(_amount);
        holderRewardLast[_holder] = block.timestamp;
        safeTokenTransfer(_holder, _amount);

    }

    // Send KOJI v2 tokens 
    function safeTokenTransfer(address _to, uint256 _amount) internal {
        tokencontractv2Interface = IBEP20(auth.getKojiEarth());
        uint256 balance = tokencontractv2Interface.balanceOf(address(this));
        uint256 amount = _amount > balance ? balance : _amount;
        tokencontractv2Interface.transfer(_to, amount);
    }

     // Safe KOJIFLUX token transfer function
    function safeFluxTransfer(address _to, uint256 _amount) internal {
        rewardtoken = IBEP20(auth.getKojiFlux()); //KOJIFLUX
        uint256 balance = rewardtoken.balanceOf(address(this));
        uint256 amount = _amount > balance ? balance : _amount;
        rewardtoken.transfer(_to, amount);
    }

    // Whether to allow the KOJI token to actually be withdrawn, of just leave it virtual (default)
    function enableKojiWithdrawals(bool _status) external onlyAuthorized {
        enableKojiWithdraw = _status;
    }

    // Whether to allow the FLUX token to actually be withdrawn, of just leave it virtual (default)
    function enableFluxWithdrawals(bool _status) external onlyAuthorized {
        enableFluxWithdraw = _status;
    }

    // View state of reward withdrawals (true/false)
    function rewardWithdrawalStatus() external view returns (bool,bool) {
        return (enableKojiWithdraw,enableFluxWithdraw);
    }

    // Withdraw KOJIFLUX
    function withdrawFluxOnly() public nonReentrant {

        require(enableFluxWithdraw, "FLUX withdrawals are not enabled");

        IKojiStaking staking = IKojiStaking(auth.getKojiStaking());

        staking.redeemTotalRewards(_msgSender());

        uint256 pending = staking.getKojiFluxBalance(_msgSender());
        if (pending > 0) {
            require(rewardtoken.balanceOf(address(this)) > pending, "FLUX token balance of this contract is insufficient");
            staking.setKojiFluxBalance(_msgSender(),0);
            safeFluxTransfer(_msgSender(), pending);
        }
        
        emit Withdraw(_msgSender(), pending);
    }

}
