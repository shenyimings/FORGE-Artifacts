// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../../libraries/TransferHelper.sol";
import "../../libraries/TimeLock.sol";
import "./interfaces/IKaiDexRouter.sol";

contract RewardSystem is Ownable, TimeLock {
   using Address for address;
    using SafeMath for uint256;
    
    /* =====================================================================================================================
                                                        Variables
    ===================================================================================================================== */
    mapping(address => bool) public _rewards;
    mapping(address => mapping(address => uint256)) public _claimTimes; //user => token => claim time
    mapping(address => bool) public _paidFee;
    uint256 public nativeSwapFee = 10; //10% fee
    uint256 public thirdPartyFee = 2; //2% fee
    uint256 public _gasCost = 6500000000000000 wei;
    
    IERC20 public _rewardToken;
    uint256 public _maxAmountPerReceive = 10000000 ether;
    uint256 public _timeBetweenClaims = 1 days;
    address public _weth = 0xAF984E23EAA3E7967F3C5E007fbe397D8566D23d;

    IKaiDexRouter public _router = IKaiDexRouter(0xbAFcdabe65A03825a131298bE7670c0aEC77B37f);
    
    /* =====================================================================================================================
                                                        Events
    ===================================================================================================================== */
    event SentRewards(address indexed owner, uint256 indexed amount, address indexed token);
    event SentRewardsETH(address indexed owner, uint256 indexed amount, uint256 indexed fees);
    event EnabledRewards(address indexed owner);
    event ChangedFee(uint256 indexed previousFee, uint256 indexed fee);
    event ChangedThirdPartyFee(uint256 indexed previousFee, uint256 indexed fee);
    event ChangedGasCost(uint256 indexed previousGas, uint256 indexed gas);
    event ChangedRewardToken(address indexed previousToken, address indexed newToken);
    event ChangedMaxAmountPerReceive(uint256 indexed previousAmount, uint256 indexed amount);
    event EmergencyWithdraw(address indexed owner);
    
    constructor(IERC20 rewardToken) {
        _rewardToken = rewardToken;
    }
    
    receive() external payable {}
    
    /* =====================================================================================================================
                                                        Get Functions
    ===================================================================================================================== */
    function getBalance(address token) public view returns (uint256) {
        if(token == address(0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }



    function canClaim(address user, address token) public view returns (bool) {
        bool isPreconditionOk = true;
        if(token != address(_rewardToken)) {
            isPreconditionOk = _paidFee[user];
        }
        return isPreconditionOk && _claimTimes[user][token] + _timeBetweenClaims <= block.timestamp;
    }
    
    
    /* =====================================================================================================================
                                                        Set Functions
    ===================================================================================================================== */

    function adjustMaxAmountPerReceive(uint256 newAmount) public onlyOwner locked("adjustMaxAmountPerReceive") {
        emit ChangedMaxAmountPerReceive(_maxAmountPerReceive, newAmount);
        _maxAmountPerReceive = newAmount;
    }
    
    function updateRewardToken(IERC20 rewardToken) public onlyOwner locked("updateRewardToken") {
        require(rewardToken != _rewardToken, "ABOAT:updateRewardToken: You can't update the exact same tokens");
        emit ChangedRewardToken(address(_rewardToken), address(rewardToken));
        _rewardToken = rewardToken;
    }
    
    function setRouter(IKaiDexRouter router) public onlyOwner {
        _router = router;
    }

    function changeFee(uint256 newFee) public onlyOwner locked("changeFee") {
        emit ChangedFee(nativeSwapFee, newFee);
        nativeSwapFee = newFee;
    }

    function changeThirdPartyFee(uint256 newFee) public onlyOwner locked("changeFee") {
        emit ChangedThirdPartyFee(thirdPartyFee, newFee);
        thirdPartyFee = newFee;
    }

    function emergencyWithdraw(address token) public onlyOwner {
        TransferHelper.safeTransfer(token, owner(), getBalance(token));
        uint256 ethBalance = address(this).balance;
        if(ethBalance > 0) {
            TransferHelper.safeTransferETH(address(owner()), ethBalance);
        }
        emit EmergencyWithdraw(owner());
    }
    
    /* =====================================================================================================================
                                                    Utility Functions
    ===================================================================================================================== */ 
    function sendRewards(uint256 amount, address user, uint256 fee, address token) public onlyOwner {
        require(address(_router) != address(0), "ABOAT::sendReward: There is no router defined to swap tokens for eth");
        require(amount <= getBalance(token), "ABOAT::sendReward: Can't send more rewards than in reward system!");
        require(amount <= _maxAmountPerReceive, "ABOAT::sendReward: Can't send more rewards than limit!");
        require(canClaim(user, token), "ABOAT::sendReward: Can't claim more than once per day");
        _claimTimes[user][token] = block.timestamp;
        if(address(_rewardToken) != token) {
            uint256 feeAmount = amount.mul(thirdPartyFee).div(100);
            uint256 userAmount = amount.sub(feeAmount);
            if(token == address(0)) {
                TransferHelper.safeTransferETH(owner(), feeAmount);
                TransferHelper.safeTransferETH(user, userAmount);
            } else {
                TransferHelper.safeTransfer(token, owner(), feeAmount);
                TransferHelper.safeTransfer(token, user, userAmount);
            }
        } else {
            require(amount > fee, "ABOAT::sendReward");
            amount = amount.sub(fee);
            uint256 userEth = address(this).balance;
            swapTokensForEth(fee);
            TransferHelper.safeTransferETH(address(owner()), address(this).balance.sub(userEth));
            TransferHelper.safeTransfer(address(_rewardToken), user, amount);
        }
        emit SentRewards(user, amount, token);
    }
    
    function sendRewardAsEth(uint256 amount, address user) public onlyOwner {
        require(address(_router) != address(0), "ABOAT::sendRewardsAsEth: There is no router defined to swap tokens for eth");
        require(amount <= getBalance(address(_rewardToken)), "ABOAT::sendRewardsAsEth: Can't send more rewards than in reward system!");
        require(amount <= _maxAmountPerReceive, "ABOAT::sendRewardsAsEth: Can't send more rewards than limit!");
        require(canClaim(user, address(_rewardToken)), "ABOAT::sendRewardsAsEth: Can't claim more than once per day");
        _claimTimes[user][address(_rewardToken)] = block.timestamp;
        uint256 ethBefore = address(this).balance;
        swapTokensForEth(amount);
        uint256 userEth = address(this).balance.sub(ethBefore);
        uint256 fee = userEth.mul(nativeSwapFee).div(100);
        userEth = userEth.sub(fee);
        TransferHelper.safeTransferETH(address(owner()), fee);
        TransferHelper.safeTransferETH(user, userEth);
        emit SentRewardsETH(user, userEth, fee);
    }

    function buyback(uint256 amount) public onlyOwner {
        require(address(this).balance > amount, "ABOAT::buyback: Not enough ETH for buyback!");
        swapEthForTokens(amount, address(_rewardToken));
    }
    
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the Enodi pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(_rewardToken);
        path[1] = _weth;

        _rewardToken.approve(address(_router), tokenAmount);

        // make the swap
        _router.swapExactTokensForKAISupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function swapEthForTokens(uint256 tokenAmount, address tokenB) private {
        address[] memory path = new address[](2);
        path[0] = _weth;
        path[1] = tokenB;
        
        _router.swapExactKAIForTokensSupportingFeeOnTransferTokens{value: tokenAmount}(
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function claim() public payable {
        require(!_paidFee[msg.sender], "ABOAT::claim: Already allowed to recieve tokens");
        require(msg.value >= _gasCost, "ABOAT::claim: Amount of bnb to claim should carry the cost to add the claimable");
        TransferHelper.safeTransferETH(owner(), msg.value);
        _paidFee[msg.sender] = true;
        emit EnabledRewards(msg.sender);
    }
}