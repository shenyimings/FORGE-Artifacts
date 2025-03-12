// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "../interfaces/ICollateralReserve.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IBasisAsset.sol";
import "../interfaces/IUniswapV2Router.sol";

contract CollateralReserve is OwnableUpgradeSafe, ICollateralReserve {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant wcro = address(0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23);

    address public usdc;
    address public router;
    address[] public shareToUsdcRouterPath;

    address public treasury;
    address public dark;
    address public share;
    address[] public collaterals;
    uint256 public shareSellingPercent;
    uint256 public maxShareAmountToSell;

    /* ========== EVENTS ========== */

    event TransferTo(address indexed token, address receiver, uint256 amount);
    event BurnToken(address indexed token, uint256 amount);
    event TreasuryUpdated(address indexed newTreasury);
    event RouterUpdated(address _router);
    event ShareSellingPercentUpdated(uint256 _shareSellingPercent);
    event MaxShareAmountToSellUpdated(uint256 _maxShareAmountToSell);
    event ShareToUsdcRouterPathUpdated(address[] _shareToUsdcRouterPath);
    event SwapToken(address inputToken, address outputToken, uint256 amount, uint256 amountReceived);

    /* ========== Modifiers =============== */

    modifier onlyTreasury() {
        require(treasury == msg.sender, "!treasury");
        _;
    }

    function initialize(address _treasury, address _dark, address _share, address[] memory _collaterals, address _router) external initializer {
        OwnableUpgradeSafe.__Ownable_init();

        require(_treasury != address(0), "zero");
        require(_collaterals.length == 3, "Invalid collateral length");
        treasury = _treasury;
        dark = _dark; // DARK
        share = _share; // NESS
        collaterals = _collaterals; // USDC, USDT, DAI
        usdc = _collaterals[0];

        router = _router;
        shareSellingPercent = 1000; // 10%
        maxShareAmountToSell = 1000 ether;

        shareToUsdcRouterPath = [_share, wcro, usdc];
    }

    /* ========== VIEWS ================ */

    function fundBalance(address _token) external override view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function transferTo(address _token, address _receiver, uint256 _amount) external override onlyTreasury {
        require(_receiver != address(0), "zero");
        require(_amount > 0, "Cannot transfer zero amount");
        IERC20(_token).safeTransfer(_receiver, _amount);
        emit TransferTo(_token, _receiver, _amount);
    }

    function burnToken(address _token, uint256 _amount) external override onlyTreasury {
        require(_amount > 0, "Cannot burn zero amount");
        IBasisAsset(_token).burn(_amount);
        emit BurnToken(_token, _amount);
    }

    function receiveDarks(uint256 _amount) external override onlyTreasury {
    }

    function receiveShares(uint256 _amount) external override onlyTreasury {
        // 1: NO TRADE
        // 2: TRADE SHARE <-> COLLATERAL
        // 3: ONLY COLLATERAL
        // 4: ONLY COLLATERAL -> BUY BACK SHARE WHEN REDEEM
        uint8 _reserve_share_state = ITreasury(treasury).reserve_share_state();
        if (_reserve_share_state == 2) {
            _sellSharesToUsdc(_amount.mul(shareSellingPercent).div(10000)); // sold some percent
        } else if (_reserve_share_state == 3) {
            _sellSharesToUsdc(IERC20(share).balanceOf(address(this))); // sold all
        }
    }

    function _sellSharesToUsdc(uint256 _amount) internal {
        if (_amount > maxShareAmountToSell) {
            _amount = maxShareAmountToSell;
        }
        uint256 _shareBal = IERC20(share).balanceOf(address(this));
        if (_amount > _shareBal) {
            _amount = _shareBal;
        }
        if (_amount == 0) return;
        IERC20(share).safeIncreaseAllowance(router, _amount);
        uint256 _before = IERC20(usdc).balanceOf(address(this));
        IUniswapV2Router(router).swapExactTokensForTokens(_amount, 1, shareToUsdcRouterPath, address(this), block.timestamp);
        uint256 _after = IERC20(usdc).balanceOf(address(this));
        emit SwapToken(share, usdc, _amount, _after.sub(_before));
    }

    function setTreasury(address _treasury) public onlyOwner {
        require(_treasury != address(0), "zero");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function setRouter(address _router) public onlyOwner {
        require(_router != address(0), "zero");
        router = _router;
        emit RouterUpdated(_router);
    }

    function setShareSellingPercent(uint256 _shareSellingPercent) public onlyOwner {
        require(_shareSellingPercent <= 10000, ">100%");
        shareSellingPercent = _shareSellingPercent;
        emit ShareSellingPercentUpdated(_shareSellingPercent);
    }

    function setMaxShareAmountToSell(uint256 _maxShareAmountToSell) public onlyOwner {
        maxShareAmountToSell = _maxShareAmountToSell;
        emit MaxShareAmountToSellUpdated(_maxShareAmountToSell);
    }

    function setShareToUsdcRouterPath(address[] memory _shareToUsdcRouterPath) public onlyOwner {
        delete shareToUsdcRouterPath;
        shareToUsdcRouterPath = _shareToUsdcRouterPath;
        emit ShareToUsdcRouterPathUpdated(_shareToUsdcRouterPath);
    }

    /* ========== EMERGENCY ========== */

    function rescueStuckErc20(address _token) external onlyOwner {
        require(_token != dark, "dark");
        require(_token != share, "share");
        for (uint256 i = 0; i < 3; i++) {
            require(_token != collaterals[i], "collateral");
        }
        IERC20(_token).safeTransfer(owner(), IERC20(_token).balanceOf(address(this)));
    }
}
