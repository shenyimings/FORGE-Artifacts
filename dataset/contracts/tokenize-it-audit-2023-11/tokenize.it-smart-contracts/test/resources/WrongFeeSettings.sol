// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../lib/forge-std/src/Test.sol";
import "../../contracts/FeeSettings.sol";

/*
    fake currency to test the main contract with
*/
contract FeeSettingsFailERC165Check0 is FeeSettings {
    constructor(Fees memory _fees, address _feeCollector) FeeSettings(address(0)) {}

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        if (interfaceId == 0x01ffc9a7) {
            return false; // signal that we don't support ERC165
        }
        // this line is never reached, but helps us to suppress a warning
        return FeeSettings.supportsInterface(interfaceId);
    }
}

contract FeeSettingsFailERC165Check1 is FeeSettings {
    constructor(Fees memory _fees, address _feeCollector) FeeSettings(address(0)) {}

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        if (interfaceId == 0x01ffc9a7) {
            return true; // signal that we support ERC165
        } else if (interfaceId == 0xffffffff) {
            return true; // signal that we don't support ERC165
        }
        return FeeSettings.supportsInterface(interfaceId);
    }
}

contract FeeSettingsFailIFeeSettingsV2Check is FeeSettings {
    constructor(Fees memory _fees, address _feeCollector) FeeSettings(address(0)) {}

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        if (interfaceId == 0x01ffc9a7) {
            return true; // signal that we support ERC165
        } else if (interfaceId == 0xffffffff) {
            return false; // signal that we support ERC165
        } else if (interfaceId == type(IFeeSettingsV2).interfaceId) {
            return false; // signal that we don't support IFeeSettingsV1
        }
        return FeeSettings.supportsInterface(interfaceId);
    }
}
