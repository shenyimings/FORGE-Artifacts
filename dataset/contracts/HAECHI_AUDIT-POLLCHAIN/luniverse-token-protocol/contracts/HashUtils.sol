pragma solidity ^0.4.24;

library HashUtils {

  function hashSideTokenId(address mainBridge, address sideBridge, uint256 _sideChainId, string _name, string _symbol, uint256 _conversionRate, uint8 _convesionRateDecimals) internal pure returns (bytes32 sideTokenId) {
    return keccak256(abi.encodePacked(mainBridge, sideBridge, _name, _symbol, _conversionRate, _convesionRateDecimals, _sideChainId));
  }

}
