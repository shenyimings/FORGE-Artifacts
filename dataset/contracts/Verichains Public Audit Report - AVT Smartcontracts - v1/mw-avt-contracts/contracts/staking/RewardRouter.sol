// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";
import "../libraries/utils/Address.sol";

import "./interfaces/IRewardTracker.sol";
import "../tokens/interfaces/IMintable.sol";
import "../tokens/interfaces/IWETH.sol";
import "../core/interfaces/IAlpManager.sol";
import "../access/Governable.sol";

contract RewardRouter is ReentrancyGuard, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    bool public isInitialized;

    address public weth;

    address public avt;
    address public esAvt;
    address public bnAvt;

    address public alp; // AVT Liquidity Provider token

    address public stakedAvtTracker;
    address public bonusAvtTracker;
    address public feeAvtTracker;

    address public stakedAlpTracker;
    address public feeAlpTracker;

    address public alpManager;

    event StakeAvt(address account, uint256 amount);
    event UnstakeAvt(address account, uint256 amount);

    event StakeAlp(address account, uint256 amount);
    event UnstakeAlp(address account, uint256 amount);

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }

    function initialize(
        address _weth,
        address _avt,
        address _esAvt,
        address _bnAvt,
        address _alp,
        address _stakedAvtTracker,
        address _bonusAvtTracker,
        address _feeAvtTracker,
        address _feeAlpTracker,
        address _stakedAlpTracker,
        address _alpManager
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        weth = _weth;

        avt = _avt;
        esAvt = _esAvt;
        bnAvt = _bnAvt;

        alp = _alp;

        stakedAvtTracker = _stakedAvtTracker;
        bonusAvtTracker = _bonusAvtTracker;
        feeAvtTracker = _feeAvtTracker;

        feeAlpTracker = _feeAlpTracker;
        stakedAlpTracker = _stakedAlpTracker;

        alpManager = _alpManager;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function batchStakeAvtForAccount(address[] memory _accounts, uint256[] memory _amounts) external nonReentrant onlyGov {
        address _avt = avt;
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeAvt(msg.sender, _accounts[i], _avt, _amounts[i]);
        }
    }

    function stakeAvtForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeAvt(msg.sender, _account, avt, _amount);
    }

    function stakeAvt(uint256 _amount) external nonReentrant {
        _stakeAvt(msg.sender, msg.sender, avt, _amount);
    }

    function stakeEsAvt(uint256 _amount) external nonReentrant {
        _stakeAvt(msg.sender, msg.sender, esAvt, _amount);
    }

    function unstakeAvt(uint256 _amount) external nonReentrant {
        _unstakeAvt(msg.sender, avt, _amount);
    }

    function unstakeEsAvt(uint256 _amount) external nonReentrant {
        _unstakeAvt(msg.sender, esAvt, _amount);
    }

    function mintAndStakeAlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minAlp) external nonReentrant returns (uint256) {
        require(_amount > 0, "RewardRouter: invalid _amount");

        address account = msg.sender;
        uint256 alpAmount = IAlpManager(alpManager).addLiquidityForAccount(account, account, _token, _amount, _minUsdg, _minAlp);
        IRewardTracker(feeAlpTracker).stakeForAccount(account, account, alp, alpAmount);
        IRewardTracker(stakedAlpTracker).stakeForAccount(account, account, feeAlpTracker, alpAmount);

        emit StakeAlp(account, alpAmount);

        return alpAmount;
    }

    function mintAndStakeAlpETH(uint256 _minUsdg, uint256 _minAlp) external payable nonReentrant returns (uint256) {
        require(msg.value > 0, "RewardRouter: invalid msg.value");

        IWETH(weth).deposit{value: msg.value}();
        IERC20(weth).approve(alpManager, msg.value);

        address account = msg.sender;
        uint256 alpAmount = IAlpManager(alpManager).addLiquidityForAccount(address(this), account, weth, msg.value, _minUsdg, _minAlp);

        IRewardTracker(feeAlpTracker).stakeForAccount(account, account, alp, alpAmount);
        IRewardTracker(stakedAlpTracker).stakeForAccount(account, account, feeAlpTracker, alpAmount);

        emit StakeAlp(account, alpAmount);

        return alpAmount;
    }

    function unstakeAndRedeemAlp(address _tokenOut, uint256 _alpAmount, uint256 _minOut, address _receiver) external nonReentrant returns (uint256) {
        require(_alpAmount > 0, "RewardRouter: invalid _alpAmount");

        address account = msg.sender;
        IRewardTracker(stakedAlpTracker).unstakeForAccount(account, feeAlpTracker, _alpAmount, account);
        IRewardTracker(feeAlpTracker).unstakeForAccount(account, alp, _alpAmount, account);
        uint256 amountOut = IAlpManager(alpManager).removeLiquidityForAccount(account, _tokenOut, _alpAmount, _minOut, _receiver);

        emit UnstakeAlp(account, _alpAmount);

        return amountOut;
    }

    function unstakeAndRedeemAlpETH(uint256 _alpAmount, uint256 _minOut, address payable _receiver) external nonReentrant returns (uint256) {
        require(_alpAmount > 0, "RewardRouter: invalid _alpAmount");

        address account = msg.sender;
        IRewardTracker(stakedAlpTracker).unstakeForAccount(account, feeAlpTracker, _alpAmount, account);
        IRewardTracker(feeAlpTracker).unstakeForAccount(account, alp, _alpAmount, account);
        uint256 amountOut = IAlpManager(alpManager).removeLiquidityForAccount(account, weth, _alpAmount, _minOut, address(this));

        IWETH(weth).withdraw(amountOut);

        _receiver.sendValue(amountOut);

        emit UnstakeAlp(account, _alpAmount);

        return amountOut;
    }

    function claim() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeAvtTracker).claimForAccount(account, account);
        IRewardTracker(feeAlpTracker).claimForAccount(account, account);

        IRewardTracker(stakedAvtTracker).claimForAccount(account, account);
        IRewardTracker(stakedAlpTracker).claimForAccount(account, account);
    }

    function claimEsAvt() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedAvtTracker).claimForAccount(account, account);
        IRewardTracker(stakedAlpTracker).claimForAccount(account, account);
    }

    function claimFees() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeAvtTracker).claimForAccount(account, account);
        IRewardTracker(feeAlpTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(address _account) external nonReentrant onlyGov {
        _compound(_account);
    }

    function batchCompoundForAccounts(address[] memory _accounts) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    function _compound(address _account) private {
        _compoundAvt(_account);
        _compoundAlp(_account);
    }

    function _compoundAvt(address _account) private {
        uint256 esAvtAmount = IRewardTracker(stakedAvtTracker).claimForAccount(_account, _account);
        if (esAvtAmount > 0) {
            _stakeAvt(_account, _account, esAvt, esAvtAmount);
        }

        uint256 bnAvtAmount = IRewardTracker(bonusAvtTracker).claimForAccount(_account, _account);
        if (bnAvtAmount > 0) {
            IRewardTracker(feeAvtTracker).stakeForAccount(_account, _account, bnAvt, bnAvtAmount);
        }
    }

    function _compoundAlp(address _account) private {
        uint256 esAvtAmount = IRewardTracker(stakedAlpTracker).claimForAccount(_account, _account);
        if (esAvtAmount > 0) {
            _stakeAvt(_account, _account, esAvt, esAvtAmount);
        }
    }

    function _stakeAvt(address _fundingAccount, address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IRewardTracker(stakedAvtTracker).stakeForAccount(_fundingAccount, _account, _token, _amount);
        IRewardTracker(bonusAvtTracker).stakeForAccount(_account, _account, stakedAvtTracker, _amount);
        IRewardTracker(feeAvtTracker).stakeForAccount(_account, _account, bonusAvtTracker, _amount);

        emit StakeAvt(_account, _amount);
    }

    function _unstakeAvt(address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        uint256 balance = IRewardTracker(stakedAvtTracker).stakedAmounts(_account);

        IRewardTracker(feeAvtTracker).unstakeForAccount(_account, bonusAvtTracker, _amount, _account);
        IRewardTracker(bonusAvtTracker).unstakeForAccount(_account, stakedAvtTracker, _amount, _account);
        IRewardTracker(stakedAvtTracker).unstakeForAccount(_account, _token, _amount, _account);

        uint256 bnAvtAmount = IRewardTracker(bonusAvtTracker).claimForAccount(_account, _account);
        if (bnAvtAmount > 0) {
            IRewardTracker(feeAvtTracker).stakeForAccount(_account, _account, bnAvt, bnAvtAmount);
        }

        uint256 stakedBnAvt = IRewardTracker(feeAvtTracker).depositBalances(_account, bnAvt);
        if (stakedBnAvt > 0) {
            uint256 reductionAmount = stakedBnAvt.mul(_amount).div(balance);
            IRewardTracker(feeAvtTracker).unstakeForAccount(_account, bnAvt, reductionAmount, _account);
            IMintable(bnAvt).burn(_account, reductionAmount);
        }

        emit UnstakeAvt(_account, _amount);
    }
}
