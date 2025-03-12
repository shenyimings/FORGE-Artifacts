// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../../libraries/TransferHelper.sol";
import "../../libraries/TimeLock.sol";

contract RewardSystem is Ownable, TimeLock {
    using Address for address;
    using SafeMath for uint256;
    
    /* =====================================================================================================================
                                                        Variables
    ===================================================================================================================== */
    mapping(address => bool) public _rewards;
    mapping(address => uint256) public _claimTimes;

    uint256 public _gasCost = 50 gwei;
    
    address public _oracleWallet = 0x76049b7cAaB30b8bBBdcfF3A1059d9147dBF7B19;
    address public _devWallet = 0xc559aCc356D3037EC6dbc33a20587051188b8634;
    
    IERC20 public _rewardToken;    
    uint256 public _maxAmountPerReceive = 10000000 ether;
    uint256 public _timeBetweenClaims = 1 days;
    
    IUniswapV2Router02 public _router = IUniswapV2Router02(0xbdd4e5660839a088573191A9889A262c0Efc0983);
    
    /* =====================================================================================================================
                                                        Events
    ===================================================================================================================== */
 event SentRewards(address indexed owner, uint256 indexed amount);
    event SentRewardsETH(address indexed owner, uint256 indexed amount, uint256 indexed fees);
    event EnabledRewards(address indexed owner);
    event ChangedGasCost(uint256 indexed previousCost, uint256 indexed cost);
    event ChangedRewardToken(address indexed previousToken, address indexed newToken);
    event ChangedOracleWallet(address indexed previousAddress, address indexed newAddress);
    event ChangedMaxAmountPerReceive(uint256 indexed previousAmount, uint256 indexed amount);
    event EmergencyWithdraw(address indexed owner);
    
    constructor(IERC20 rewardToken) {
        _rewardToken = rewardToken;
        changeOracleWallet(_oracleWallet);
    }
    
    receive() external payable {}
    
    /* =====================================================================================================================
                                                        Get Functions
    ===================================================================================================================== */
    function getBalance() public view returns (uint256) {
        return _rewardToken.balanceOf(address(this));
    }

    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function canClaim(address user) public view returns (bool) {
        return _rewards[user] && canClaimNative(user);
    }

    function canClaimNative(address user) public view returns (bool) {
        return _claimTimes[user] + _timeBetweenClaims <= block.timestamp;
    }
    
    /* =====================================================================================================================
                                                        Set Functions
    ===================================================================================================================== */
    
    function adjustGasCost(uint256 gasCost) public onlyOwner locked("adjustGasCost") {
        emit ChangedGasCost(_gasCost, gasCost);
        _gasCost = gasCost;
    }

    function adjustMaxAmountPerReceive(uint256 newAmount) public onlyOwner locked("adjustMaxAmountPerReceive") {
        emit ChangedMaxAmountPerReceive(_maxAmountPerReceive, newAmount);
        _maxAmountPerReceive = newAmount;
    }
    
    function updateRewardToken(IERC20 rewardToken) public onlyOwner locked("updateRewardToken") {
        require(rewardToken != _rewardToken, "ABOAT:updateRewardToken: You can't update the exact same tokens");
        emit ChangedRewardToken(address(_rewardToken), address(rewardToken));
        _rewardToken = rewardToken;
    }
    
    function changeOracleWallet(address oracleWallet) public onlyOwner locked("changeOracleWallet") {
        transferOwnership(oracleWallet);
        address previous = _oracleWallet;
        _oracleWallet = oracleWallet;
        emit ChangedOracleWallet(previous, _oracleWallet);
    }
    
    function setRouter(IUniswapV2Router02 router) public onlyOwner {
        _router = router;
    }

    function emergencyWithdraw() public onlyOwner {
        TransferHelper.safeTransfer(address(_rewardToken), owner(), getBalance());
        emit EmergencyWithdraw(owner());
    }
    
    /* =====================================================================================================================
                                                    Utility Functions
    ===================================================================================================================== */ 

    function sendRewards(uint256[] memory amounts, address[] memory addresses) public onlyOwner {
        require(amounts.length == addresses.length, "ABOAT::sendRewards: amounts and addresses must have the same amount of entries");
        
        for(uint index = 0; index < addresses.length; index++) {
            if(_rewards[addresses[index]] && getBalance() >= amounts[index] && canClaim(addresses[index]) && amounts[index] <= _maxAmountPerReceive) {
                _rewards[addresses[index]] = false;
                _claimTimes[addresses[index]] = block.timestamp;
                TransferHelper.safeTransfer(address(_rewardToken), addresses[index], amounts[index]);
                emit SentRewards(addresses[index], amounts[index]);
            }
        }
    }

    function sendRewardsNew(uint256[] memory amounts, address[] memory addresses) public onlyOwner {
        require(amounts.length == addresses.length, "ABOAT::sendRewards: amounts and addresses must have the same amount of entries");
        
        for(uint index = 0; index < addresses.length; index++) {
            if(_rewards[addresses[index]] && getBalance() >= amounts[index] && canClaim(addresses[index]) && amounts[index] <= _maxAmountPerReceive) {
                _rewards[addresses[index]] = false;
                _claimTimes[addresses[index]] = block.timestamp;
                TransferHelper.safeTransfer(address(_rewardToken), addresses[index], amounts[index]);
                emit SentRewards(addresses[index], amounts[index]);
            }
        }
    }
    
    function sendRewardsAsEth(uint256 amount, address user) public onlyOwner {
        require(address(_router) != address(0), "ABOAT::sendRewardsAsEth: There is no router defined to swap tokens for eth");
        require(amount <= getBalance(), "ABOAT::sendRewardsAsEth: Can't send more rewards than in reward system!");
        require(amount <= _maxAmountPerReceive, "ABOAT::sendRewardsAsEth: Can't send more rewards than limit!");
        require(canClaimNative(user), "ABOAT::sendRewardsAsEth: Can't claim more than once per day");
        _claimTimes[user] = block.timestamp;
        swapTokensForEth(amount);
        uint256 userEth = address(this).balance.sub(_gasCost);
        TransferHelper.safeTransferETH(_oracleWallet, _gasCost);
        uint256 fee = userEth.div(10);
        userEth = userEth.sub(fee);
        TransferHelper.safeTransferETH(_devWallet, fee);
        TransferHelper.safeTransferETH(user, userEth);
        emit SentRewardsETH(user, userEth, fee);
    }

    
    
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the Enodi pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(_rewardToken);
        path[1] = _router.WETH();

        _rewardToken.approve(address(_router), tokenAmount);

        // make the swap
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
    
    function sendRewardAndAdjustGasCost(uint256[] memory amounts, address[] memory addresses, uint256 gasCost) public onlyOwner {
        adjustGasCost(gasCost);
        sendRewards(amounts, addresses);
    }
    
    function claim() public payable {
        require(!_rewards[msg.sender], "ABOAT::claim: Already allowed to recieve tokens");
        require(msg.value >= _gasCost, "ABOAT::claim: Amount of bnb to claim should carry the cost to add the claimable");
        TransferHelper.safeTransferETH(_oracleWallet, msg.value);
        _rewards[msg.sender] = true;
        emit EnabledRewards(msg.sender);
    }
}