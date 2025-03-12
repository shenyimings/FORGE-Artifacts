// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
pragma abicoder v2;

import "./helpers/DustRefunder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../interfaces/IMintableERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../../../interfaces/radiant/IMultiFeeDistribution.sol";
import "../../../interfaces/IWETH.sol";

/// @title Borrow gate via stargate
/// @author Radiant
/// @dev All function calls are currently implemented without side effects
contract LockZapMock is Initializable, DustRefunder {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /// @notice RAITO Divisor
    uint256 public constant RATIO_DIVISOR = 10000;

    /// @notice Acceptable ratio
    uint256 public ACCEPTABLE_RATIO = 9500;

    /// @notice Wrapped ETH
    IWETH public weth;

    /// @notice RDNT token address
    address public rdntAddr;
    address public rdntWeth;

    /// @notice Multi Fee distribution contract
    IMultiFeeDistribution public mfd;

    /// @notice Emitted when zap is done
    event Zapped(
        bool _borrow,
        uint256 _ethAmt,
        uint256 _rdntAmt,
        address indexed _from,
        address indexed _onBehalf,
        uint256 _lockTypeIndex
    );

    uint256 public ethLPRatio = 2000; // paramter to set the ratio of ETH in the LP token, can be 2000 for an 80/20 bal lp

    /**
     * @notice Initializer
     * @param _weth weth address
     * @param _rdntAddr RDNT token address
     */
    constructor(IWETH _weth, address _rdntAddr, address _rdntWeth) initializer {
        weth = _weth;
        rdntAddr = _rdntAddr;
        rdntWeth = _rdntWeth;
    }

    receive() external payable {}

    /**
     * @notice Set Multi fee distribution contract.
     * @param _mfdAddr New contract address.
     */
    function setMfd(address _mfdAddr) external {
        require(address(_mfdAddr) != address(0), "MFD can't be 0 address");
        mfd = IMultiFeeDistribution(_mfdAddr);
    }

    /**
     * @notice Get quote from the pool
     * @param _tokenAmount amount of tokens.
     */
    function quoteFromToken(uint256 _tokenAmount) public pure returns (uint256 optimalWETHAmount) {
        if (_tokenAmount < 26770) {
            return 0;
        }
        optimalWETHAmount = _tokenAmount / 26770;
    }

    /**
     * @notice Zap tokens to stake LP
     * @param _borrow option to borrow ETH
     * @param _wethAmt amount of weth.
     * @param _rdntAmt amount of RDNT.
     * @param _lockTypeIndex lock length index.
     */
    function zap(
        bool _borrow,
        uint256 _wethAmt,
        uint256 _rdntAmt,
        uint256 _lockTypeIndex
    ) public payable returns (uint256 liquidity) {
        return
            _zap(_borrow, _wethAmt, _rdntAmt, msg.sender, msg.sender, _lockTypeIndex, msg.sender);
    }

    /**
     * @notice Zap into LP
     * @param _borrow option to borrow ETH
     * @param _wethAmt amount of weth.
     * @param _rdntAmt amount of RDNT.
     * @param _from src address of RDNT
     * @param _onBehalf of the user.
     * @param _lockTypeIndex lock length index.
     * @param _refundAddress dust is refunded to this address.
     */
    function _zap(
        bool _borrow,
        uint256 _wethAmt,
        uint256 _rdntAmt,
        address _from,
        address _onBehalf,
        uint256 _lockTypeIndex,
        address _refundAddress
    ) internal returns (uint256 liquidity) {
        require(_wethAmt != 0 || msg.value != 0, "ETH required");
        if (msg.value != 0) {
            require(!_borrow, "invalid zap ETH source");
            _wethAmt = msg.value;
            weth.deposit{ value: _wethAmt }();
        } else {
            if (_borrow) {
                // _executeBorrow(_wethAmt);
            } else {
                weth.transferFrom(msg.sender, address(this), _wethAmt);
            }
        }
        //case where rdnt is matched with borrowed ETH
        if (_rdntAmt != 0) {
            require(_wethAmt >= quoteFromToken(_rdntAmt), "ETH sent is not enough");

            // _from == this when zapping from vesting
            if (_from != address(this)) {
                IERC20(rdntAddr).safeTransferFrom(msg.sender, address(this), _rdntAmt);
            }
            liquidity = valueInUsd(0, _rdntAmt);
            IMintableERC20(rdntWeth).mint(address(this), liquidity);
        } else {
            liquidity = valueInUsd(_wethAmt, 0);
            IMintableERC20(rdntWeth).mint(address(this), liquidity);
        }

        IERC20(rdntWeth).safeApprove(address(mfd), liquidity);
        mfd.stake(liquidity, _onBehalf, _lockTypeIndex);
        emit Zapped(_borrow, _wethAmt, _rdntAmt, _from, _onBehalf, _lockTypeIndex);

        refundDust(rdntAddr, address(weth), _refundAddress);
    }

    function valueInUsd(
        uint256 _wethAmt,
        uint256 _rdntAmt
    ) internal pure returns (uint256 _liquidity) {
        uint256 usdtAmount;
        if (_wethAmt != 0) {
            usdtAmount = _wethAmt * 1728; // 1 ETH = 1728 USD
            _liquidity = usdtAmount - ((usdtAmount * 20) / 100);
        } else {
            usdtAmount = (_rdntAmt * 26) / 100; // 1 RDNT = 0.26 USD
            _liquidity = usdtAmount - ((usdtAmount * 20) / 100);
        }
    }
}
