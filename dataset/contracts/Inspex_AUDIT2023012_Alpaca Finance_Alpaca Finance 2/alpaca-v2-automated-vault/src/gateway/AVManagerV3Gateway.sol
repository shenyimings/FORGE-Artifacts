// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

// libraries
import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { IWNative } from "src/libraries/IWNative.sol";

// interfaces
import { IAVManagerV3Gateway } from "src/interfaces/IAVManagerV3Gateway.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

contract AVManagerV3Gateway is IAVManagerV3Gateway {
  using SafeTransferLib for ERC20;

  AutomatedVaultManager public immutable vaultManager;
  address public immutable wNativeToken;

  constructor(address _vaultManager, address _wNativeToken) {
    // sanity check
    AutomatedVaultManager(_vaultManager).vaultTokenImplementation();
    ERC20(_wNativeToken).decimals();

    vaultManager = AutomatedVaultManager(_vaultManager);
    wNativeToken = _wNativeToken;
  }

  function deposit(address _vaultToken, address _token, uint256 _amount, uint256 _minReceived)
    external
    returns (bytes memory _result)
  {
    if (_amount == 0) {
      revert AVManagerV3Gateway_InvalidInput();
    }

    // pull token
    ERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

    // approve AVManagerV3Gateway to vault manager
    ERC20(_token).safeApprove(address(vaultManager), _amount);

    // build deposit params
    AutomatedVaultManager.TokenAmount[] memory _depositParams = _getDepositParams(_token, _amount);
    _result = vaultManager.deposit(msg.sender, _vaultToken, _depositParams, _minReceived);
  }

  function depositETH(address _vaultToken, uint256 _minReceived) external payable returns (bytes memory _result) {
    if (msg.value == 0) {
      revert AVManagerV3Gateway_InvalidInput();
    }
    // convert native to wrap
    IWNative(wNativeToken).deposit{ value: msg.value }();

    // approve AVManagerV3Gateway to vault manager
    ERC20(wNativeToken).safeApprove(address(vaultManager), msg.value);

    // build deposit params
    AutomatedVaultManager.TokenAmount[] memory _depositParams = _getDepositParams(wNativeToken, msg.value);
    // deposit (check slippage inside here)
    _result = vaultManager.deposit(msg.sender, _vaultToken, _depositParams, _minReceived);
  }

  function withdrawMinimize(
    address _vaultToken,
    uint256 _shareToWithdraw,
    AutomatedVaultManager.TokenAmount[] calldata _minAmountOut
  ) external returns (AutomatedVaultManager.TokenAmount[] memory _result) {
    // withdraw
    _result = _withdraw(_vaultToken, _shareToWithdraw, _minAmountOut);
    // check native
    uint256 _length = _result.length;
    for (uint256 _i; _i < _length;) {
      if (_result[_i].token == wNativeToken) {
        IWNative(wNativeToken).withdraw(_result[_i].amount);
        SafeTransferLib.safeTransferETH(msg.sender, _result[_i].amount);
      } else {
        ERC20(_result[_i].token).safeTransfer(msg.sender, _result[_i].amount);
      }

      unchecked {
        ++_i;
      }
    }
  }

  function withdrawConvertAll(address _vaultToken, uint256 _shareToWithdraw, bool _zeroForOne, uint256 _minAmountOut)
    external
    returns (uint256 _amountOut)
  {
    // dump token0 <> token1
    address _worker = vaultManager.getWorker(_vaultToken);
    ERC20 _token0 = PancakeV3Worker(_worker).token0();
    ERC20 _token1 = PancakeV3Worker(_worker).token1();
    ICommonV3Pool _pool = PancakeV3Worker(_worker).pool();

    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts = new AutomatedVaultManager.TokenAmount[](2);
    _minAmountOuts[0].token = address(_token0);
    _minAmountOuts[0].amount = 0;
    _minAmountOuts[1].token = address(_token1);
    _minAmountOuts[1].amount = 0;

    // withdraw
    _withdraw(_vaultToken, _shareToWithdraw, _minAmountOuts);

    ERC20 _tokenOut;
    uint256 _amountIn;
    if (_zeroForOne) {
      _tokenOut = _token1;
      _amountIn = _token0.balanceOf(address(this));
    } else {
      _tokenOut = _token0;
      _amountIn = _token1.balanceOf(address(this));
    }

    // skip swap when amount = 0
    if (_amountIn > 0) {
      _pool.swap(
        address(this),
        _zeroForOne,
        int256(_amountIn),
        _zeroForOne ? LibTickMath.MIN_SQRT_RATIO + 1 : LibTickMath.MAX_SQRT_RATIO - 1,
        abi.encode(address(_token0), address(_token1), _pool.fee())
      );
    }

    _amountOut = _tokenOut.balanceOf(address(this));
    if (_amountOut < _minAmountOut) {
      revert AVManagerV3Gateway_TooLittleReceived();
    }

    // check native
    // transfer to user
    if (address(_tokenOut) == wNativeToken) {
      IWNative(wNativeToken).withdraw(_amountOut);
      SafeTransferLib.safeTransferETH(msg.sender, _amountOut);
    } else {
      _tokenOut.safeTransfer(msg.sender, _amountOut);
    }
  }

  function _getDepositParams(address _token, uint256 _amount)
    internal
    pure
    returns (AutomatedVaultManager.TokenAmount[] memory)
  {
    AutomatedVaultManager.TokenAmount[] memory _depositParams = new AutomatedVaultManager.TokenAmount[](1);
    _depositParams[0] = AutomatedVaultManager.TokenAmount({ token: _token, amount: _amount });
    return _depositParams;
  }

  function pancakeV3SwapCallback(int256 _amount0Delta, int256 _amount1Delta, bytes calldata _data) external {
    (address _token0, address _token1, uint24 _fee) = abi.decode(_data, (address, address, uint24));
    address _pool = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              hex"ff",
              0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9,
              keccak256(abi.encode(_token0, _token1, _fee)),
              bytes32(0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2)
            )
          )
        )
      )
    );

    if (msg.sender != _pool) {
      revert AVManagerV3Gateway_NotPool();
    }

    if (_amount0Delta > 0) {
      ERC20(_token0).safeTransfer(msg.sender, uint256(_amount0Delta));
    } else {
      ERC20(_token1).safeTransfer(msg.sender, uint256(_amount1Delta));
    }
  }

  function _withdraw(
    address _vaultToken,
    uint256 _shareToWithdraw,
    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts
  ) internal returns (AutomatedVaultManager.TokenAmount[] memory _result) {
    // pull token
    ERC20(_vaultToken).safeTransferFrom(msg.sender, address(this), _shareToWithdraw);
    // withdraw
    _result = vaultManager.withdraw(_vaultToken, _shareToWithdraw, _minAmountOuts);
  }

  receive() external payable { }
}
