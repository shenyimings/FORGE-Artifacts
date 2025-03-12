// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../../dependencies/interfaces/IStore.sol";
import "../../dependencies/interfaces/ICxToken.sol";
import "../../util/interfaces/IThrowable.sol";

abstract contract ProofOfPolicy is IThrowable {
  error InvalidProofError();
  error ExpiredProofError(uint256 expiredOn);
  error InsufficientNpmBalanceError(uint256 minRequired);

  function _getNpm(IStore s) internal view returns (IERC20Upgradeable) {
    bytes32 CNS_NPM = "cns:core:npm:instance";
    return IERC20Upgradeable(s.getAddress(CNS_NPM));
  }

  function _throwIfInvalidProof(IStore s, ICxToken proof, address account) internal view {
    // Ensure that the submitted proof is authentic
    bytes32 key = keccak256(abi.encodePacked(bytes32("ns:cover:cxtoken"), proof));

    if (s.getBool(key) == false) {
      revert AccessDeniedError("cxToken");
    }

    // Ensure that the submitted proof is acceptable
    if (proof.balanceOf((account)) == 0) {
      revert InvalidProofError();
    }

    // Ensure that the submitted proof is active
    if (proof.expiresOn() < block.timestamp) {
      revert ExpiredProofError(proof.expiresOn());
    }

    if (_getNpm(s).balanceOf(account) < 10 ether) {
      revert InsufficientNpmBalanceError(10 ether);
    }
  }
}
