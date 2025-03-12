// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract InitializedProxy {
    address public immutable logic;

    constructor(
        address _logic,
        bytes memory _initializationCalldata
    ) {
        logic = _logic;
        // Initialize metodunu çalıştırmak için delegatecall yap
        (bool _ok, bytes memory returnData) =
            _logic.delegatecall(_initializationCalldata);
        // Delegatecall başarılı mı kontrol et
        require(_ok, string(returnData));
    }

    fallback() external payable {
        address _impl = logic;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
                case 0 {
                    revert(ptr, size)
                }
                default {
                    return(ptr, size)
                }
        }
    }

    receive() external payable {}
}