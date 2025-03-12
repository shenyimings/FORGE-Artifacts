// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./token/BEP20/BEP20.sol";

contract KuKachuBscTest is AccessControl, BEP20, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    mapping (address => uint256) private _cooldownOf;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => uint256) private _bnbBalanceOf;

    uint256 private _buyBackBnbBalance = 0;

    string private _name = 'KuKachu.com';
    string private _symbol = 'KUKA';
    uint8 private immutable _decimals = 9;

    uint16 internal constant _DIV = 1000;
    uint256 private constant _INITIAL_BALANCE = 100000 * 10 ** 6 * 10 ** 9;

    IUniswapV2Router02 private _router;
    address private _routerAddress;
    IUniswapV2Pair private _pair;
    address private _pairAddress;
    address[] private _tokenPath = new address[](2);
    address[] private _wbscPath = new address[](2);

    address private _thisAddress;
    address payable private  _devAddress;
    address payable private _marketingAddress;
    address payable private _rewardAddress;
    address private constant _BURNADDRESS = address(0x000000000000000000000000000000000000dEaD);
    
    uint256 private _launchTime;
    bool private _tokenCreated;
    bool private _contractIsLaunched = false;
    bool private _swapAndLiquifyEnabled = false;
    bool private _midSwap;
    bool private _isSell;

    uint256 private constant _MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _maxTxAmount;
    uint256 private _maxHolding;
    uint256 private _minTokensToSell;
    uint256 private constant _COOLDOWN = 2 minutes;//4 hours;
    bool private _contractRestriction;

    // 12% tax
    uint256 private constant _BURN_FEE = 10;
    uint256 private constant _DEVELOPER_FEE = 10;
    uint256 private constant _MARKETING_FEE = 20;
    uint256 private constant _REWARD_FEE = 40;
    uint256 private constant _DAT = 20;
    uint256 private constant _LPFEE = 20;

    // total to swap for liquidity = 9%
    uint256 private _totalToSwap = _DEVELOPER_FEE + _MARKETING_FEE + _REWARD_FEE + _LPFEE;

    //buyback 4%
    uint256 private constant _BUYBACK_FEE = 40;
    uint256 private _totalToSwapWithBuyBack = _totalToSwap + _BUYBACK_FEE;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EXCLUDED = keccak256("EXCLUDED");

    event LpAdded(uint256 bnbAdded, uint256 tokensAdded);
    event BnbAdded(address account, uint256 bnbAdded);
    event ClaimedBnb(address recipient, uint256 bnbAmount);
    event CoolDownSet(address account, uint256 time);

    constructor(IUniswapV2Router02 router_, address payable developerAddress_, address payable marketingAddress_, address payable rewardAddress_) BEP20(_name, _symbol){
        _thisAddress = address(this);
        _devAddress = developerAddress_;
        _marketingAddress = marketingAddress_;
        _rewardAddress = rewardAddress_;

        _router = router_;
        _routerAddress = address(_router);
        _pairAddress = IUniswapV2Factory(_router.factory()).createPair(_thisAddress, _router.WETH());
        _pair = IUniswapV2Pair(_pairAddress);
        _tokenPath[0] = _thisAddress;
        _tokenPath[1] = _router.WETH();
        _wbscPath[0] = _router.WETH();
        _wbscPath[1] = _thisAddress;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _devAddress);
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, _devAddress);

        _setupRole(EXCLUDED, _msgSender());
        _setupRole(EXCLUDED, _thisAddress);
        _setupRole(EXCLUDED, _BURNADDRESS);
        _setupRole(EXCLUDED, _devAddress);
        _setupRole(EXCLUDED, _marketingAddress);
        _setupRole(EXCLUDED, _rewardAddress);
    }
    receive() external payable {}
    fallback () external payable {}

    /**
     * @dev Activate the contract by adding liquidity.
     *
     * Trick bots adding LP for different name without the ability to trade
     *
     */
    function activate() external {
        require(!_tokenCreated, 'KuKachu: Token already created');
        require(_thisAddress.balance >= 1 ether, 'Contract requires a balance of at least 50 BNB to create the token'); 

        _tTotal = _INITIAL_BALANCE;
        _rTotal = (_MAX - (_MAX % _tTotal));
        uint256 tInitialLP = _tTotal.mul(100).div(_DIV);
        uint256 rInitialLP = reflectionFromToken(tInitialLP, false);
        uint256 tWitelist = _tTotal.mul(300).div(_DIV);
        uint256 rWitelist = reflectionFromToken(tWitelist, false);
        uint256 tInitialBurn = _tTotal.mul(600).div(_DIV);
        uint256 rInitialBurn = reflectionFromToken(tInitialBurn, false);
        _minTokensToSell = _tTotal.mul(1).div(10000).div(10); // 0.001% max tx amount will trigger swap and add liquidity
        _maxTxAmount = _tTotal.mul(5).div(_DIV);
        _maxHolding = _tTotal.mul(10).div(_DIV);
        _rOwned[_thisAddress] = rInitialLP;
        _rOwned[devAddress()] = rWitelist;
        _rOwned[burnAddress()] = rInitialBurn;
        emit Transfer(address(0), _thisAddress, tInitialLP);
        emit Transfer(address(0), devAddress(), tWitelist);
        emit Transfer(address(0), burnAddress(), tInitialBurn);
        _midSwap = true;
        _approve(_thisAddress, routerAddress(), _MAX);
        _addLiquidity(_thisAddress.balance, balanceOf(_thisAddress));
        _midSwap = false;
        _tokenCreated = true;
        _swapAndLiquifyEnabled = true;
        _contractRestriction = true;
        _isSell = false;
    }

    /**
     * @dev Launch the contract
     *
     * The ability to buy/sell/transfer
     *
     * Verify the contract after activation
     * Can only call once!
     *
     */
    function launch() external onlyRole(ADMIN_ROLE) {
        require(_tokenCreated, 'KuKachu: token not created yet');
        require(!_contractIsLaunched, "KuKachu: contract is launched");
        _contractIsLaunched = true;
        _launchTime = block.timestamp;
    }

    function setNewRewardAddress(address payable rewardAddress_) external onlyRole(ADMIN_ROLE) {
        require(rewardAddress_ != address(0), 'KuKachu: rewardAddress zero address');
        require(rewardAddress_ != rewardAddress(), 'KuKachu: rewardAddress is the same address');
        _rewardAddress = rewardAddress_;
    }

    function setSwapAndLiquifyEnabled(bool swapAndLiquifyEnabled_) external onlyRole(ADMIN_ROLE) {
        _swapAndLiquifyEnabled = swapAndLiquifyEnabled_;
    }

    function setContractRestriction(bool contractRestriction_) external onlyRole(ADMIN_ROLE) {
        _contractRestriction = contractRestriction_;
    }

    /**
     * @dev claim BNB and send to DEV wallet.
     *
     * DEV Must have BNB balance
     *
     */
    function claimDevBnb() external nonReentrant {
        uint256 devBnbBalance = bnbBalanceOf(devAddress());
        _beforeClaim(devAddress());
        (bool success,) = payable(devAddress()).call{value: devBnbBalance}("");
        if (success) _bnbBalanceOf[devAddress()] = 0;
        emit ClaimedBnb(devAddress(), devBnbBalance);
    }

    /**
     * @dev claim BNB and send to MARKETING wallet.
     *
     * MARKETING Must have BNB balance
     *
     */
    function claimMarketingBnb() external nonReentrant {
        uint256 marketingBnbBalance = bnbBalanceOf(marketingAddress()) ;
        _beforeClaim(marketingAddress());
        (bool success,) = payable(marketingAddress()).call{value: marketingBnbBalance}("");
        if (success) _bnbBalanceOf[marketingAddress()] = 0;
        emit ClaimedBnb(marketingAddress(), marketingBnbBalance);
    }

    function flipAndBurn() public {
        require(isIsLaunched(), 'KuKachu: Contract not launched yet');
        require(_thisAddress.balance > 0, 'Not enough BNB in contract');
        require(bnbBalanceOfBuyBack() > 0, 'Not enough BNB in buy back vault');
        if (!_midSwap) _flipAndBurnTokens(bnbBalanceOfBuyBack());
    }

    /**
     * @dev claim BNB and send to REWARD staking contract.
     *
     * REWARD Must have BNB balance
     *
     */
    function claimRewardBnb() external nonReentrant {
        uint256 rewardBnbBalance = bnbBalanceOf(rewardAddress()) ;
        _beforeClaim(rewardAddress());
        require(rewardAddress() != _thisAddress, "KuKachu: reward is this address");
        (bool success,) = payable(rewardAddress()).call{value: rewardBnbBalance}("");
        if (success) _bnbBalanceOf[rewardAddress()] = 0;
        emit ClaimedBnb(marketingAddress(), rewardBnbBalance);
    }

    //REMOVE AFTER TESTING!!!!
    function fallbackBNB() external nonReentrant {
        uint256 bnbBalance = _thisAddress.balance;
        uint256 leftOver = bnbBalance.sub(bnbBalanceOfBuyBack()).sub(bnbBalanceOf(rewardAddress())).sub(bnbBalanceOf(devAddress())).sub(bnbBalanceOf(marketingAddress()));
        require(bnbBalance > 0, "KuKachu, contract has zero BNB balance");
        require(leftOver > 0, "KuKachu, leftOver BNB is zero");
        (bool sent,) = address(devAddress()).call{value : leftOver}("");
        require(sent, "KuKachu: cannot withdraw");
        emit ClaimedBnb(devAddress(), leftOver);
    }

    function fallbackRedeem(IERC20 newToken_, uint256 tokenAmount_) external nonReentrant {
        require(address(newToken_) != _thisAddress, "KuKachu: cannot recover to $KUKA");
        require(address(newToken_) != pairAddress(), "KuKachu: cannot recover to $CAKE LP");
        newToken_.safeTransfer(devAddress(), tokenAmount_);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (account == pairAddress()) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function bnbBalanceOf(address account) public view returns (uint256) {
        return _bnbBalanceOf[account];
    }

    function bnbBalanceOfBuyBack() public view returns (uint256) {
        return _buyBackBnbBalance;
    }

    function tokenCreated() public view returns (bool) {
        return _tokenCreated;
    }

    function burnAddress() public pure returns(address) {
        return _BURNADDRESS;
    }

    function devAddress() public view returns(address) {
        return _devAddress;
    }

    function marketingAddress() public view returns(address) {
        return _marketingAddress;
    }

    function rewardAddress() public view returns(address) {
        return _rewardAddress;
    }

    function routerAddress() public view returns(address) {
        return _routerAddress;
    }

    function pairAddress() public view returns(address) {
        return _pairAddress;
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "KuKachu: rAmount greater than total reflections");
        return rAmount.div(_getRate());
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        (uint256 rAmount,uint256 rTransferAmount,,,,) = _getTxValues(tAmount);
        if (!deductTransferFee) return rAmount;
        return rTransferAmount;
    }

    function maxTxAmount() public view returns(uint256) {
        return _maxTxAmount;
    }

    function maxHoldingAmount() public view returns(uint256) {
        return _maxHolding;
    }

    function cooldownOf(address account) public view returns (uint256) {
        return _cooldownOf[account];
    }

    function isIsLaunched() public view returns (bool) {
        return _contractIsLaunched;
    }

    function launchTime() public view returns (uint256) {
        return _launchTime;
    }

    function isswapAndLiquifyEnabled() public view returns (bool) {
        return _swapAndLiquifyEnabled;
    }

    function isContractRestricted() public view returns (bool) {
        return _contractRestriction;
    }

    function _transferFromPool(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rDat, uint256 rTotalToSwap, uint256 tTransferAmount,) = _getTxValues(tAmount); 
        (uint256 rBurn, uint256 tBurn) = _getTxBValues(tAmount);
        rTransferAmount = rTransferAmount.sub(rBurn);
        tTransferAmount = tTransferAmount.sub(tBurn);
        uint256 tTotalToSwap = tokenFromReflection(rTotalToSwap);
        _tOwned[pairAddress()] = _tOwned[pairAddress()].sub(tAmount);
        _rOwned[pairAddress()] = _rOwned[pairAddress()].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _rOwned[burnAddress()] = _rOwned[burnAddress()].add(rBurn);
        _rOwned[_thisAddress] = _rOwned[_thisAddress].add(rTotalToSwap);
        _rTotal = _rTotal.sub(rDat);
        emit Transfer(sender, burnAddress(), tBurn);
        emit Transfer(sender, _thisAddress, tTotalToSwap);
        emit Transfer(sender, recipient, tTransferAmount);
        _setCooldownOf(recipient);
    }

    function _transferToPool(address sender, address recipient, uint256 tAmount) private {
        require(cooldownOf(sender) <= block.timestamp, "KuKachu: cooldown period for sender");
        (uint256 rAmount, uint256 rTransferAmount, uint256 rDat, uint256 rTotalToSwap, uint256 tTransferAmount,) = _getTxValuesOnSell(tAmount); 
        (uint256 rBurn, uint256 tBurn) = _getTxBValues(tAmount);
        rTransferAmount = rTransferAmount.sub(rBurn);
        tTransferAmount = tTransferAmount.sub(tBurn);
        uint256 tTotalToSwap = tokenFromReflection(rTotalToSwap);
        _isSell = true;
        _swapAndAddLp();
        _isSell = false;
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _rOwned[burnAddress()] = _rOwned[burnAddress()].add(rBurn);
        _rOwned[_thisAddress] = _rOwned[_thisAddress].add(rTotalToSwap);
        _rTotal = _rTotal.sub(rDat);
        emit Transfer(sender, burnAddress(), tBurn);
        emit Transfer(sender, _thisAddress, tTotalToSwap);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        require(cooldownOf(sender) <= block.timestamp, "KuKachu: cooldown period for sender"); // REMOVE AFTER TESTING
        (uint256 rAmount, uint256 rTransferAmount, uint256 rDat, uint256 rTotalToSwap, uint256 tTransferAmount,) = _getTxValues(tAmount); 
        (uint256 rBurn, uint256 tBurn) = _getTxBValues(tAmount);
        rTransferAmount = rTransferAmount.sub(rBurn);
        tTransferAmount = tTransferAmount.sub(tBurn);
        uint256 tTotalToSwap = tokenFromReflection(rTotalToSwap);
        _swapAndAddLp();
        _rOwned[sender] =  _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _rOwned[burnAddress()] = _rOwned[burnAddress()].add(rBurn);
        _rOwned[_thisAddress] = _rOwned[_thisAddress].add(rTotalToSwap);
        _rTotal = _rTotal.sub(rDat);
        if (tAmount >= _minTokensToSell) {
            //to avoid cheating: if more than 0.001% max tx amount sent cooldown will be set for recipient
            _setCooldownOf(recipient);
        }
        emit Transfer(sender, burnAddress(), tBurn);
        emit Transfer(sender, _thisAddress, tTotalToSwap);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromPoolNoFees(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount,,,,,) = _getTxValues(tAmount);
        _tOwned[pairAddress()] = _tOwned[pairAddress()].sub(tAmount);
        _rOwned[pairAddress()] = _rOwned[pairAddress()].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rAmount);
        emit Transfer(sender, recipient, tAmount);
    }

    function _transferToPoolNoFees(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount,,,,,) = _getTxValues(tAmount);
        _rOwned[sender] =  _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rAmount);
        emit Transfer(sender, recipient, tAmount);
    }

    function _transferStandaardNoFees(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount,,,,,) = _getTxValues(tAmount);
        _rOwned[sender] =  _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rAmount);
        emit Transfer(sender, recipient, tAmount);
    }

    function _getTxValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tDat, uint256 tTotalToSwap) = _getTValues(tAmount);
        uint256 currentRate =  _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rDat, uint256 rTotalToSwap) = _getRValues(tAmount, tDat, tTotalToSwap, currentRate);
        return (rAmount, rTransferAmount, rDat, rTotalToSwap, tTransferAmount, currentRate);
    }

    function _getTxValuesOnSell(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tDat, uint256 tTotalToSwap) = _getTValuesOnSell(tAmount);
        uint256 currentRate =  _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rDat, uint256 rTotalToSwap) = _getRValues(tAmount, tDat, tTotalToSwap, currentRate);
        return (rAmount, rTransferAmount, rDat, rTotalToSwap, tTransferAmount, currentRate);
    }

    function _getTxBValues(uint256 tAmount) private view returns (uint256, uint256) {
        uint256 tBurn = _getTBValues(tAmount);
        uint256 currentRate =  _getRate();
        uint256 rBurn = _getRBValues(tBurn, currentRate);
        return (rBurn, tBurn);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tTotalToSwap = tAmount.mul( _totalToSwap).div(_DIV);
        uint256 tDat = tAmount.mul(_DAT).div(_DIV);
        uint256 tTransferAmount = tAmount.sub(tDat).sub(tTotalToSwap);
        return (tTransferAmount, tDat, tTotalToSwap);
    }

    function _getTValuesOnSell(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tTotalToSwap = tAmount.mul( _totalToSwapWithBuyBack).div(_DIV);
        uint256 tDat = tAmount.mul(_DAT).div(_DIV);
        uint256 tTransferAmount = tAmount.sub(tDat).sub(tTotalToSwap);
        return (tTransferAmount, tDat, tTotalToSwap);
    }

    function _getTBValues(uint256 tAmount) private pure returns (uint256) {
        uint256 tBurn = tAmount.mul(_BURN_FEE).div(_DIV);
        return tBurn;
    }

    function _getRValues(uint256 tAmount, uint256 tDat, uint256 tTotalToSwap, uint256 currentRate) private pure returns (uint256, uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rDat = tDat.mul(currentRate);
        uint256 rTotalToSwap = tTotalToSwap.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rDat).sub(rTotalToSwap);
        return (rAmount, rTransferAmount, rDat, rTotalToSwap);
    }

    function _getRBValues(uint256 tBurn,uint256 currentRate) private pure returns (uint256) {
        uint256 rBurn = tBurn.mul(currentRate);
        return rBurn;
    }

    function _getRate() private view returns(uint256) {
        return (_rTotal.sub(_rOwned[pairAddress()])).div(_tTotal.sub(_tOwned[pairAddress()]));
    }
    
    function _swapAndAddLp() private {
        uint256 initialBalance = balanceOf(_thisAddress);

        uint256 lpTokensBalance =  initialBalance.mul(_LPFEE).div(_DIV);
        uint256 lpTokensToAdd = lpTokensBalance.div(2);

        uint256 tokenAmountToBeSwapped;
        bool shouldSell;
        uint256 lpPercent;
        uint256 rewardPercent;
        uint256 devPercent;
        uint256 marketingPercent;
        uint256 buyBackPercent;
        if (_isSell) {
            shouldSell = true;
            tokenAmountToBeSwapped = initialBalance.sub(lpTokensToAdd);
            lpPercent = _LPFEE.mul(_DIV).div(_totalToSwapWithBuyBack);
            rewardPercent = _REWARD_FEE.mul(_DIV).div(_totalToSwapWithBuyBack);
            devPercent = _DEVELOPER_FEE.mul(_DIV).div(_totalToSwapWithBuyBack);
            marketingPercent = _MARKETING_FEE.mul(_DIV).div(_totalToSwapWithBuyBack);
            buyBackPercent = _BUYBACK_FEE.mul(_DIV).div(_totalToSwapWithBuyBack);
        } else {
            tokenAmountToBeSwapped = initialBalance.sub(lpTokensToAdd);
            shouldSell = tokenAmountToBeSwapped >= _minTokensToSell;
            lpPercent = _LPFEE.mul(_DIV).div(_totalToSwap);
            rewardPercent = _REWARD_FEE.mul(_DIV).div(_totalToSwap);
            devPercent = _DEVELOPER_FEE.mul(_DIV).div(_totalToSwap);
            marketingPercent = _MARKETING_FEE.mul(_DIV).div(_totalToSwap);
        }

        if (shouldSell && isswapAndLiquifyEnabled()) {
            _midSwap = true;
            if (allowance(_thisAddress, routerAddress()) < tokenAmountToBeSwapped) _approve(_thisAddress, routerAddress(), _MAX);
            uint256 bnbBalance = _thisAddress.balance;
            _swapTokensForBnb(tokenAmountToBeSwapped);
            uint256 bnbReceived = _thisAddress.balance.sub(bnbBalance);
            if (bnbReceived > 0) {
                // split the bnbReceived balances
                uint256 lpPart = bnbReceived.mul(lpPercent).div(_DIV);
                uint256 rewardPart = bnbReceived.mul(rewardPercent).div(_DIV);
                uint256 developerPart = bnbReceived.mul(devPercent).div(_DIV);
                uint256 marketingPart = bnbReceived.mul(marketingPercent).div(_DIV);
                if (_isSell) {
                    uint256 buyBackPart =  bnbReceived.mul(buyBackPercent).div(_DIV);
                    _buyBackBnbBalance += buyBackPart;
                    emit BnbAdded(_thisAddress, buyBackPart);
                }

                _bnbBalanceOf[rewardAddress()] += rewardPart;
                _bnbBalanceOf[devAddress()] += developerPart;
                _bnbBalanceOf[marketingAddress()] += marketingPart; 
                emit BnbAdded(rewardAddress(), rewardPart);
                emit BnbAdded(devAddress(), developerPart);
                emit BnbAdded(marketingAddress(), marketingPart);

                _addLiquidity(lpPart, lpTokensToAdd);       
                emit LpAdded(lpPart, lpTokensToAdd);
            }
            _midSwap = false;
        }
    }

    function _flipAndBurnTokens(uint256 bnbAmount) private {
        _midSwap = true;
        uint256 tBalance = balanceOf(burnAddress());
        _swapBnbForTokens(bnbAmount);
        uint256 tReceived = balanceOf(burnAddress()).sub(tBalance);
        uint256 rReceived = reflectionFromToken(tReceived, false);
        _buyBackBnbBalance = _buyBackBnbBalance.sub(bnbAmount);
        _rOwned[burnAddress()] = _rOwned[burnAddress()].sub(rReceived);
        _rTotal = _rTotal.sub(rReceived);
        _tTotal = _tTotal.sub(tReceived);
        emit Transfer(address(0), burnAddress(), tReceived);
        _midSwap = false;
    }
    
    function _swapTokensForBnb(uint256 swapAmount) private {
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(swapAmount, 0, _tokenPath, _thisAddress, block.timestamp);
    }

    function _swapBnbForTokens(uint256 bscAmount) private {
        _router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: bscAmount}(0, _wbscPath, burnAddress(), block.timestamp);
    }

    function _addLiquidity(uint256 bscAmount, uint256 tokenAmount) private {
        _router.addLiquidityETH{value: bscAmount}(_thisAddress, tokenAmount, 0, 0, _msgSender(), block.timestamp);
    }

    function _setCooldownOf(address recipient) internal {
        uint256 cooldownPeriod = block.timestamp + _COOLDOWN;
        _cooldownOf[recipient] = cooldownPeriod;
        emit CoolDownSet(recipient, cooldownPeriod);
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        require(balanceOf(sender) >= amount, "BEP20: transfer amount exceeds balance");

        if (!_tokenCreated) {
            // during activation
            _transferToPoolNoFees(sender, recipient, amount);
        } else if (sender == pairAddress()) {
            // buy or remove LP
            if (hasRole(EXCLUDED, recipient)) {
                _transferFromPoolNoFees(sender, recipient, amount);
            } else {
                 if (!_midSwap) {
                    require(amount + balanceOf(recipient) <= maxHoldingAmount(), "KuKachu: _transfer #1 amount exceeds the maxTxAmount");
                    if(isContractRestricted()) {
                        require(!recipient.isContract(), "KuKachu: recipient is a contract address");
                        require(tx.origin == recipient, "KuKachu: recipient is a contract address");
                    }
                 }
                _transferFromPool(sender, recipient, amount);
            }
        } else if (recipient == pairAddress()) {
            // sell or add LP
            if (hasRole(EXCLUDED, sender)) {
                _transferToPoolNoFees(sender, recipient, amount);
            } else {
                // TEST change to 1 day (not able to sell the first day)
                if (!_midSwap) require(block.timestamp >= launchTime() + 5 minutes, "KuKachu: not able to sell the first day"); 
                _transferToPool(sender, recipient, amount);
            }
        } else {
            if (hasRole(EXCLUDED, sender) || hasRole(EXCLUDED, recipient)) {
                if (!hasRole(EXCLUDED, recipient)) {
                    if (!_midSwap) require(amount + balanceOf(recipient) <= maxHoldingAmount(), "KuKachu: _transfer #2 amount exceeds the maxHoldingAmount");
                }
                _transferStandaardNoFees(sender, recipient, amount);
            } else {
                if (!_midSwap) {
                    require(amount <= maxTxAmount(), "KuKachu: _transfer #2 amount exceeds the maxTxAmount");
                    require(amount + balanceOf(recipient) <= maxHoldingAmount(), "KuKachu: _transfer #3 amount exceeds the maxHoldingAmount");
                    if(isContractRestricted()) {
                        require(!sender.isContract(), "KuKachu: recipient is a contract address");
                        require(tx.origin == msg.sender, "KuKachu: recipient is a contract address");
                    }
                }
                _transferStandard(sender, recipient, amount);
            }
        }
        super._afterTokenTransfer(sender, recipient, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(amount > 0, "KuKachu: transfer zero amount");
        
        if (from == pairAddress()) {
            // buy or remove LP #1
            if (!_midSwap) {
                require(_contractIsLaunched, "KuKachu: contract is not launched");
                require(amount <= maxTxAmount(), "KuKachu: _beforeTokenTransfer #1 amount exceeds the maxTxAmount");
            }
        } else if (to == pairAddress()) {
            // sell or add LP #2
            if (!_midSwap) {
                require(_contractIsLaunched, "KuKachu: contract is not launched");
                require(amount <= maxTxAmount(), "KuKachu: _beforeTokenTransfer #2 amount exceeds the maxTxAmount");
            }
        }
    }

    function _beforeClaim(address account) internal virtual {
        require(_contractIsLaunched, "KuKachu: contract is not launched");
        require(_thisAddress.balance > 0, "KuKachu, contract zero BNB balance");
        require(bnbBalanceOf(account) > 0, "KuKachu, BNB balanceOf is zero");
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }
}