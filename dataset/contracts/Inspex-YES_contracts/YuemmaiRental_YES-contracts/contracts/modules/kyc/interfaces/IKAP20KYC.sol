// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "./IKYCBitkubChain.sol";

interface IKAP20KYC {
  event ActivateOnlyKYCAddress();
  event SetKYC(address oldKyc, address newKyc);
  event SetAccecptedKycLevel(uint256 oldKycLevel, uint256 newKycLevel);

  function activateOnlyKycAddress() external;
  function setKYC(address _kyc) external;
  function setAcceptedKycLevel(uint256 _kycLevel) external;

  function kyc() external returns(IKYCBitkubChain);
  function acceptedKycLevel() external returns(uint256);
  function isActivatedOnlyKycAddress() external returns(bool);
}