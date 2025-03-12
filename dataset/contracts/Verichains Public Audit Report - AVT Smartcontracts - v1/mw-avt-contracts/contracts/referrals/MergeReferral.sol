// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./interfaces/IMergeReferralStorage.sol";
import "../peripherals/interfaces/ITimelockTarget.sol";

contract MergeReferral {
    address admin;

    constructor() public {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: forbidden");
        _;
    }

    function getCodeOwners(
        IMergeReferralStorage _referralStorage,
        bytes32[] memory _codes
    ) public view returns (address[] memory) {
        address[] memory owners = new address[](_codes.length);

        for (uint256 i = 0; i < _codes.length; i++) {
            bytes32 code = _codes[i];
            owners[i] = _referralStorage.codeOwners(code);
        }

        return owners;
    }

    function mergeTraderReferral(
        address oldReferralStorage,
        address newReferralStorage,
        address[] calldata _accountArr
    ) external onlyAdmin {
        uint256 length = _accountArr.length;
        for (uint256 i = 0; i < length; i++) {
            address account = _accountArr[i];

            (bytes32 oldTraderReferralCode, ) = IMergeReferralStorage(oldReferralStorage).getTraderReferralInfo(
                account
            );
            (bytes32 newTraderReferralCode, ) = IMergeReferralStorage(newReferralStorage).getTraderReferralInfo(
                account
            );
            if (oldTraderReferralCode != newTraderReferralCode) {
                IMergeReferralStorage(newReferralStorage).govSetTraderReferralCode(account, oldTraderReferralCode);
            }
        }
    }

    function mergeCodeOwner(
        address oldReferralStorage,
        address newReferralStorage,
        bytes32[] calldata _codeArr
    ) external onlyAdmin {
        uint256 length = _codeArr.length;
        for (uint256 i = 0; i < length; i++) {
            bytes32 code = _codeArr[i];

            address oldCodeOwner = IMergeReferralStorage(oldReferralStorage).codeOwners(code);
            address newCodeOwner = IMergeReferralStorage(newReferralStorage).codeOwners(code);
            if (oldCodeOwner != newCodeOwner) {
                IMergeReferralStorage(newReferralStorage).govSetCodeOwner(code, oldCodeOwner);
            }
        }
    }

    function setGov(address _target, address _gov) external onlyAdmin {
        ITimelockTarget(_target).setGov(_gov);
    }
}
