// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

// import "@animoca/ethereum-contracts-core-1.1.1/contracts/introspection/IERC165.sol";
// import "./ICoreMetadataDelegator.sol";
// import "./ICoreMetadata.sol";

// /**
//  * @dev Abstract Core Metadata Delegator contract.
//  */
// abstract contract CoreMetadataDelegator is ICoreMetadataDelegator, IERC165 {
//     address public override coreMetadataImplementer;

//     constructor() internal {
//         // _registerInterface(type(ICoreMetadataDelegator).interfaceId);
//     }

//     function _setInventoryMetadataImplementer(address implementer) internal {
//         require(IERC165(implementer).supportsInterface(type(ICoreMetadata).interfaceId), "MetaDeleg: invalid implementer");
//         coreMetadataImplementer = implementer;
//     }
// }
