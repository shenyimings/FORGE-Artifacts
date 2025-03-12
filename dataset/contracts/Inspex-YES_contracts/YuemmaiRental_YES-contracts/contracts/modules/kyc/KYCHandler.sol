// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IKYCBitkubChain.sol";
import "./interfaces/IKAP20KYC.sol";

abstract contract KYCHandler is IKAP20KYC {
  IKYCBitkubChain public override kyc;

  uint256 public override acceptedKycLevel;
  bool public override isActivatedOnlyKycAddress;

  constructor(address kyc_, uint256 acceptedKycLevel_) {
    kyc = IKYCBitkubChain(kyc_);
    acceptedKycLevel = acceptedKycLevel_;
  }

  function _activateOnlyKycAddress() internal virtual {
    isActivatedOnlyKycAddress = true;
    emit ActivateOnlyKYCAddress();
  }

  function _setKYC(IKYCBitkubChain _kyc) internal virtual {
    IKYCBitkubChain oldKyc = kyc;
    kyc = _kyc;
    emit SetKYC(address(oldKyc), address(kyc));
  }

  function _setAcceptedKycLevel(uint256 _kycLevel) internal virtual {
    uint256 oldKycLevel = acceptedKycLevel;
    acceptedKycLevel = _kycLevel;
    emit SetAccecptedKycLevel(oldKycLevel, acceptedKycLevel);
  }
}