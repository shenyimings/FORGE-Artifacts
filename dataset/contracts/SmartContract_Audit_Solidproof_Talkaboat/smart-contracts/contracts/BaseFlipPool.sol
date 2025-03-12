// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.7;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./interfaces/IMasterChefContractor.sol";
import "./flip_interfaces/IPancakeSwapMasterChef.sol";
import "./libraries/TransferHelper.sol";

contract BaseFlipPool is Ownable, IMasterChefContractor {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;    
    
    /* =====================================================================================================================
                                                        Variables
    ===================================================================================================================== */
    IPancakeSwapMasterChef masterChef;
    IERC20 public rewardToken;  //What do we get as reward?
    IERC20 public stakeToken;   //What do we stake to get reward?
    IERC20 public flipToken;    //What do we swap to?
    address public rewardSystem;
    
    IUniswapV2Router02 router;
    
    address masterEntertainer;
    
    uint256 public minAmountToSwap = 1 ether;
    /* =====================================================================================================================
                                                        Events
    ===================================================================================================================== */
    event SetRewardSystem(address indexed user, address indexed newAddress);
    event SetMasterEntertainer(address indexed masterEntertainer);
    event SetRouter(address indexed router);
    event SetMinAmountToSwap(uint256 amount);
    /* =====================================================================================================================
                                                        Modifier
    ===================================================================================================================== */
    modifier onlyMasterEntertainer {
        require(address(msg.sender) == masterEntertainer, "ABOAT::onlyMasterEntertainer: Only the master entertainer is allowed to call this method!");
        _;
    }
    
    
    constructor(IERC20 _flipToken, IERC20 _stakeToken, IERC20 _rewardToken, address _rewardSystem, IPancakeSwapMasterChef _masterChef, address _masterEntertainer) {
        require(address(_flipToken) != address(0), "Flip Token can't be zero address");
        require(address(_stakeToken) != address(0), "Stake Token can't be zero address");
        require(address(_rewardToken) != address(0), "Reward Token can't be zero address");
        require(_rewardSystem != address(0), "Reward System can't be zero address");
        require(address(_masterChef) != address(0), "Master Chef can't be zero address");
        require(_masterEntertainer != address(0), "Master Entertainer can't be zero address");
        flipToken = _flipToken;
        masterChef = _masterChef;
        masterEntertainer = _masterEntertainer;
        stakeToken = _stakeToken;
        rewardToken = _rewardToken;
        rewardSystem = _rewardSystem;
    }  

    /* =====================================================================================================================
                                                        Set Functions
    ===================================================================================================================== */
    function setRewardSystem(address _rewardSystem) public onlyOwner{
        require(_rewardSystem != address(0), "Reward System can't be set to zero address");
        rewardSystem = _rewardSystem;
        emit SetRewardSystem(msg.sender, rewardSystem);
    }
    
    function setRouter(IUniswapV2Router02 _router) public onlyOwner {
        require(address(_router) != address(0), "Router can't be set to zero address");
        router = _router;
        emit SetRouter(address(router));
    }
    
    function setMasterEntertainer(address _masterEntertainer) public onlyOwner {
        require(_masterEntertainer != address(0), "Master Entertainer can't be set to zero address");
        masterEntertainer = _masterEntertainer;
        emit SetMasterEntertainer(masterEntertainer);
    }
    
    function setMinAmountToSwap(uint256 _minAmount) public onlyOwner {
        minAmountToSwap = _minAmount;
        emit SetMinAmountToSwap(minAmountToSwap);
    }
    
    /* =====================================================================================================================
                                                        Get Functions
    ===================================================================================================================== */
    function getMasterChef() external override view returns (address) {
        return address(masterChef);
    }
    
    function getLiquidity(uint256 _pid) external override view returns (uint256) {
        (uint256 amount, ) = masterChef.userInfo(_pid, address(this));
        return amount;
    }
    
    function getDepositFee(uint256 _pid) external override view returns (uint256) {
        return 0;
    }
    
    /* =====================================================================================================================
                                                    Utility Functions
    ===================================================================================================================== */
    receive() external payable {}
    
    function deposit(uint256 _pid, uint256 _amount) external override onlyMasterEntertainer {
        _deposit(_pid, _amount);
    }
    
    function _deposit(uint256 _pid, uint256 _amount) internal {
        stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        stakeToken.approve(address(masterChef), _amount);
        if(_pid == 0) {
            enterStake(_pid, _amount);
        } else {
            masterChef.deposit(_pid, _amount);
        }
        swapToken();
    }
    
    function withdraw(uint256 _pid, uint256 _amount, address _sender) external override onlyMasterEntertainer {
        if(_pid == 0) {
            leaveStake(_pid, _amount);
        } else {
            masterChef.withdraw(_pid, _amount);
        }
        if(_amount > 0) {
            stakeToken.safeTransfer(_sender, _amount);
        }
        swapToken();
    }
    
    
    function emergencyWithdraw(uint256 _pid, uint256 _amount, address _sender) external override onlyMasterEntertainer {
        masterChef.withdrawWithoutRewards(_pid);
        safeTokenTransfer(stakeToken, _sender, _amount);
        _deposit(_pid, stakeToken.balanceOf(address(this)));
        
    }
    
    function enterStake(uint256 _pid, uint256 _amount) internal {
        masterChef.deposit(_pid, _amount);
        swapToken();
    }
    
    function leaveStake(uint256 _pid, uint256 _amount) internal {
        masterChef.withdraw(_pid, _amount);
    }
    
    
    function swapToken() internal {
        uint256 balanceToSwap = rewardToken.balanceOf(address(this));
        if(address(router) == address(0) && balanceToSwap > 0) {
            safeTokenTransfer(rewardToken, owner(), balanceToSwap);
        }
        else if(balanceToSwap >= minAmountToSwap) {
            uint256 ethBalance = swapForEth(rewardToken, balanceToSwap);
            swapEthForTokens(ethBalance);
        }
       
    }
    
    function swapForEth(IERC20 token, uint256 amount) internal returns (uint256) {
        uint256 initialBalance = address(this).balance;
                
        // swap tokens for ETH
        swapTokensForEth(token, amount);
        
        return address(this).balance.sub(initialBalance);
    }
    
    function swapTokensForEth(IERC20 token, uint256 tokenAmount) internal {
        // generate the Enodi pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = router.WETH();

        token.approve(address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
    
    function swapEthForTokens(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(flipToken);
        
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: tokenAmount}(
            0, // accept any amount of ETH
            path,
            rewardSystem,
            block.timestamp
        );
    }
    
    function safeTokenTransfer(IERC20 token, address _to, uint256 _amount) internal {
        uint256 tokenBalance = token.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > tokenBalance) {
            transferSuccess = token.transfer(_to, tokenBalance);
        } else {
            transferSuccess = token.transfer(_to, _amount);
        }
        require(transferSuccess, "ABOAT::safeTokenTransfer: transfer failed");
    }
    
}