// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.11;

interface IXPYT {
  function DOMAIN_SEPARATOR (  ) external view returns ( bytes32 );
  function allowance ( address, address ) external view returns ( uint256 );
  function approve ( address spender, uint256 amount ) external returns ( bool );
  function asset (  ) external view returns ( address );
  function assetBalance (  ) external view returns ( uint256 );
  function balanceOf ( address ) external view returns ( uint256 );
  function convertToAssets ( uint256 shares ) external view returns ( uint256 );
  function convertToShares ( uint256 assets ) external view returns ( uint256 );
  function decimals (  ) external view returns ( uint8 );
  function deposit ( uint256 assets, address receiver ) external returns ( uint256 shares );
  function gate (  ) external view returns ( address );
  function maxDeposit ( address ) external view returns ( uint256 );
  function maxMint ( address ) external view returns ( uint256 );
  function maxRedeem ( address owner ) external view returns ( uint256 );
  function maxWithdraw ( address owner ) external view returns ( uint256 );
  function minOutputMultiplier (  ) external view returns ( uint256 );
  function mint ( uint256 shares, address receiver ) external returns ( uint256 assets );
  function multicall ( bytes[] memory data ) external returns ( bytes[] memory results );
  function name (  ) external view returns ( string memory );
  function nonces ( address ) external view returns ( uint256 );
  function nyt (  ) external view returns ( address );
  function permit ( address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s ) external;
  function pound ( address pounderRewardRecipient ) external returns ( uint256 yieldAmount, uint256 pytCompounded, uint256 pounderReward );
  function pounderRewardMultiplier (  ) external view returns ( uint256 );
  function previewDeposit ( uint256 assets ) external view returns ( uint256 );
  function previewMint ( uint256 shares ) external view returns ( uint256 );
  function previewPound (  ) external returns ( uint8 errorCode, uint256 yieldAmount, uint256 pytCompounded, uint256 pounderReward );
  function previewRedeem ( uint256 shares ) external view returns ( uint256 );
  function previewWithdraw ( uint256 assets ) external view returns ( uint256 );
  function redeem ( uint256 shares, address receiver, address owner ) external returns ( uint256 assets );
  function selfPermit ( address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s ) external;
  function selfPermitIfNecessary ( address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s ) external;
  function sweep ( address receiver ) external returns ( uint256 shares );
  function symbol (  ) external view returns ( string memory );
  function totalAssets (  ) external view returns ( uint256 );
  function totalSupply (  ) external view returns ( uint256 );
  function transfer ( address to, uint256 amount ) external returns ( bool );
  function transferFrom ( address from, address to, uint256 amount ) external returns ( bool );
  function uniswapV3Factory (  ) external view returns ( address );
  function uniswapV3PoolFee (  ) external view returns ( uint24 );
  function uniswapV3Quoter (  ) external view returns ( address );
  function uniswapV3SwapCallback ( int256 amount0Delta, int256 amount1Delta, bytes memory data ) external;
  function uniswapV3TwapSecondsAgo (  ) external view returns ( uint32 );
  function vault (  ) external view returns ( address );
  function withdraw ( uint256 assets, address receiver, address owner ) external returns ( uint256 shares );
}

