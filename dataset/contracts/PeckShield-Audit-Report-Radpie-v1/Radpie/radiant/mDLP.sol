// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../interfaces/IRadiantStaking.sol";
import "../interfaces/IMasterRadpie.sol";
import "../interfaces/radiant/IMultiFeeDistribution.sol";
import "../interfaces/radiant/IPoolHelper.sol";
import "../interfaces/radiant/IPriceProvider.sol";
import "../interfaces/chainlink/AggregatorV3Interface.sol";
import "../interfaces/IWETH.sol";

/// @title mDLP
/// @author Magpie Team
/// @notice mDLP is a token minted when 1 ETH/BNB deposit on Radpie, the deposit is irreversible, user will get mDLP instead.
contract mDLP is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    /* ============ State Variables ============ */

    address public rdnt;
    address public rdntDlp;
    address public radiantStaking;
    address public masterRadpie;

    uint8 constant STAKEMODE = 1;

    /* ============ State Variables ============ */

    IWETH public weth;
    IPoolHelper public dlpPoolHelper;
    IPriceProvider public priceProvider;
    AggregatorV3Interface public ethOracle;
    uint256 public constant RATIO_DIVISOR = 10000;
    uint256 public constant ACCEPTABLE_RATIO = 9500;
    uint256 public ethLPRatio;

    /* ============ Events ============ */

    event mDLPConverted(address indexed _user, uint256 _amount, uint256 _mode);
    event RadiantStakingSet(address indexed _radiantStaking);
    event masterRadpieSet(address indexed _masterRadpie);
    event NativeConverted(uint256 _amount, uint256 _liquidity);
    event DlpConverted(uint256 _amount, uint256 _liquidity);
    event RdntConverted(uint256 _amount, uint256 _liquidity);
    event Zapped(address indexed _user, uint256 _ethAmt, uint256 _rdntAmt, uint256 _dlpAmount);

    /* ============ Errors ============ */

    error MasterRadpieNotSet();
    error RadiantStakingNotSet();
    error InvalidAmount();
    error AddressZero();
    error BeyondSlippage();
    error EthShort();

    /* ============ Constructor ============ */

    function __mDLP_init(
        address _rdnt,
        address _rdntDlp,
        address _radiantStaking,
        address _masterRadpie
    ) public initializer {
        __ERC20_init("Magpie locked DLP", "mDLP");
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        rdnt = _rdnt;
        rdntDlp = _rdntDlp;
        masterRadpie = _masterRadpie;
        radiantStaking = _radiantStaking;
    }

    /* ============ External Functions ============ */

    function convertWithZapRadiant(
        address _for,
        uint256 _rdntAmt,
        uint8 _mode
    ) public payable nonReentrant whenNotPaused returns (uint256) {
        if (msg.value == 0) revert InvalidAmount();

        uint256 _wethAmt = msg.value;
        uint256 liquidity = _zapRadiant(_rdntAmt, _wethAmt);

        IERC20(rdntDlp).safeTransfer(radiantStaking, liquidity);

        _mintMDLP(_for, liquidity, _mode);

        emit Zapped(msg.sender, _wethAmt, _rdntAmt, liquidity);

        _refundDust(_for);

        return liquidity;
    }

    function zapRadiantForDLP(
        address _for,
        uint256 _rdntAmt
    ) public payable nonReentrant whenNotPaused returns (uint256) {
        if (msg.value == 0) revert InvalidAmount();

        uint256 _wethAmt = msg.value;
        uint256 liquidity = _zapRadiant(_rdntAmt, _wethAmt);

        IERC20(rdntDlp).safeTransfer(_for, liquidity);

        emit Zapped(msg.sender, _wethAmt, _rdntAmt, liquidity);

        _refundDust(_for);

        return liquidity;
    }

    function convertWithLp(
        address _for,
        uint256 _amount,
        uint8 _mode
    ) external nonReentrant whenNotPaused {
        IERC20(rdntDlp).safeTransferFrom(msg.sender, radiantStaking, _amount);
        _mintMDLP(_for, _amount, _mode);
    }

    /* ============ Internal Functions ============ */

    /// @notice deposit ETH/BNB in magpie finance and get mDLP at a 1:1 rate
    /// @param _mode 0 doing nothing, 1 is convert and stake
    function _mintMDLP(address _for, uint256 _amount, uint8 _mode) internal {
        if (_mode == STAKEMODE) {
            if (masterRadpie == address(0)) revert MasterRadpieNotSet();
            _mint(address(this), _amount);

            IERC20(address(this)).safeApprove(address(masterRadpie), _amount);
            IMasterRadpie(masterRadpie).depositFor(address(this), _for, _amount);

            emit mDLPConverted(_for, _amount, _mode);
        } else {
            _mint(_for, _amount);
            emit mDLPConverted(msg.sender, _amount, 0);
        }
    }

    function _refundDust(address _refundAddress) internal {
        uint256 dustWETH = weth.balanceOf(address(this));
        if (dustWETH > 0) {
            weth.transfer(_refundAddress, dustWETH);
        }
        uint256 dustRdnt = IERC20(rdnt).balanceOf(address(this));
        if (dustRdnt > 0) {
            IERC20(rdnt).safeTransfer(_refundAddress, dustRdnt);
        }
    }

    function _calcSlippage(uint256 _ethAmt, uint256 _liquidity) internal returns (uint256 ratio) {
        priceProvider.update();
        uint256 priceWETHamount = (_ethAmt * (uint256(ethOracle.latestAnswer()))) / (1E18);
        uint256 priceLPamount = _liquidity * priceProvider.getLpTokenPriceUsd();
        ratio = (priceLPamount * (RATIO_DIVISOR)) / (priceWETHamount);
        ratio = ratio / (1E18);
    }

    function _zapRadiant(uint256 _rdntAmt, uint256 _wethAmt) internal returns (uint256) {
        uint256 liquidity; // received dlp amount
        weth.deposit{ value: _wethAmt }();

        IERC20(weth).safeApprove(address(dlpPoolHelper), _wethAmt);
        uint256 totalWethValueIn;

        if (_rdntAmt != 0) {
            if (_wethAmt < dlpPoolHelper.quoteFromToken(_rdntAmt)) revert EthShort();

            IERC20(rdnt).transferFrom(msg.sender, address(this), _rdntAmt);
            IERC20(rdnt).safeApprove(address(dlpPoolHelper), _rdntAmt);
            liquidity = dlpPoolHelper.zapTokens(_wethAmt, _rdntAmt);
            totalWethValueIn = (_wethAmt * (RATIO_DIVISOR)) / (ethLPRatio);
        } else {
            liquidity = dlpPoolHelper.zapWETH(_wethAmt);
            totalWethValueIn = _wethAmt;
        }

        if (address(priceProvider) != address(0)) {
            uint256 slippage = _calcSlippage(totalWethValueIn, liquidity);
            if (slippage < ACCEPTABLE_RATIO) revert BeyondSlippage();
        }

        return liquidity;
    }

    /* ============ Admin Functions ============ */

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setRadiantStaking(address _radiantStaking) external onlyOwner {
        if (radiantStaking == address(0)) revert AddressZero();

        radiantStaking = _radiantStaking;
        emit RadiantStakingSet(radiantStaking);
    }

    function setMasterRadpie(address _masterRadPie) external onlyOwner {
        if (_masterRadPie == address(0)) revert AddressZero();

        masterRadpie = _masterRadPie;
        emit masterRadpieSet(masterRadpie);
    }


    function initZap(
        address _weth,
        address _dlpPoolHelper,
        address _ethOracle,
        address _priceProvider,
        uint256 _ethLPRatio
    ) external onlyOwner {
        weth = IWETH(_weth);
        dlpPoolHelper = IPoolHelper(_dlpPoolHelper);
        ethOracle = AggregatorV3Interface(_ethOracle);
        priceProvider = IPriceProvider(_priceProvider);
        ethLPRatio = _ethLPRatio;
    }
}
