// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.11;

interface IERC4626Gate {
  function beforePerpetualYieldTokenTransfer ( address from, address to, uint256 amount, uint256 fromBalance, uint256 toBalance ) external;
  function claimOwnership (  ) external;
  function claimYieldAndEnter ( address nytRecipient, address pytRecipient, address vault, address xPYT ) external returns ( uint256 yieldAmount );
  function claimYieldInUnderlying ( address recipient, address vault ) external returns ( uint256 yieldAmount );
  function claimYieldInVaultShares ( address recipient, address vault ) external returns ( uint256 yieldAmount );
  function computeYieldPerToken ( address vault ) external view returns ( uint256 );
  function emergencyExitNegativeYieldToken ( address vault, uint256 amount, address recipient ) external returns ( uint256 underlyingAmount );
  function emergencyExitPerpetualYieldToken ( address vault, address xPYT, uint256 amount, address recipient ) external returns ( uint256 underlyingAmount );
  function emergencyExitStatusOfVault ( address ) external view returns ( bool activated, uint96 pytPriceInUnderlying );
  function enterWithUnderlying ( address nytRecipient, address pytRecipient, address vault, address xPYT, uint256 underlyingAmount ) external returns ( uint256 mintAmount );
  function enterWithVaultShares ( address nytRecipient, address pytRecipient, address vault, address xPYT, uint256 vaultSharesAmount ) external returns ( uint256 mintAmount );
  function exitToUnderlying ( address recipient, address vault, address xPYT, uint256 underlyingAmount ) external returns ( uint256 burnAmount );
  function exitToVaultShares ( address recipient, address vault, address xPYT, uint256 vaultSharesAmount ) external returns ( uint256 burnAmount );
  function factory (  ) external view returns ( address );
  function getClaimableYieldAmount ( address vault, address user ) external view returns ( uint256 yieldAmount );
  function getNegativeYieldTokenForVault ( address vault ) external view returns ( address );
  function getPerpetualYieldTokenForVault ( address vault ) external view returns ( address );
  function getPricePerVaultShare ( address vault ) external view returns ( uint256 );
  function getUnderlyingOfVault ( address vault ) external view returns ( address );
  function getVaultShareBalance ( address vault ) external view returns ( uint256 );
  function multicall ( bytes[] memory data ) external returns ( bytes[] memory results );
  function negativeYieldTokenName ( address vault ) external view returns ( string memory );
  function negativeYieldTokenSymbol ( address vault ) external view returns ( string memory );
  function owner (  ) external view returns ( address );
  function ownerActivateEmergencyExitForVault ( address vault, uint96 pytPriceInUnderlying ) external;
  function ownerDeactivateEmergencyExitForVault ( address vault ) external;
  function pendingOwner (  ) external view returns ( address );
  function perpetualYieldTokenName ( address vault ) external view returns ( string memory );
  function perpetualYieldTokenSymbol ( address vault ) external view returns ( string memory );
  function pricePerVaultShareStored ( address ) external view returns ( uint256 );
  function selfPermit ( address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s ) external;
  function selfPermitIfNecessary ( address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s ) external;
  function transferOwnership ( address newOwner, bool direct, bool renounce ) external;
  function userAccruedYield ( address, address ) external view returns ( uint256 );
  function userYieldPerTokenStored ( address, address ) external view returns ( uint256 );
  function vaultSharesIsERC20 (  ) external pure returns ( bool );
  function yieldPerTokenStored ( address ) external view returns ( uint256 );
}

