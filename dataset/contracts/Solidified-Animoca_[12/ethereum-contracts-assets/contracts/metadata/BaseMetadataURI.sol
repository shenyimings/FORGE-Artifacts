// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {ManagedIdentity, Ownable} from "@animoca/ethereum-contracts-core-1.1.1/contracts/access/Ownable.sol";
import {UInt256ToDecimalString} from "@animoca/ethereum-contracts-core-1.1.1/contracts/utils/types/UInt256ToDecimalString.sol";

abstract contract BaseMetadataURI is ManagedIdentity, Ownable {
    using UInt256ToDecimalString for uint256;

    event BaseMetadataURISet(string baseMetadataURI);

    string public baseMetadataURI;

    function setBaseMetadataURI(string calldata baseMetadataURI_) external {
        _requireOwnership(_msgSender());
        baseMetadataURI = baseMetadataURI_;
        emit BaseMetadataURISet(baseMetadataURI_);
    }

    function _uri(uint256 id) internal view virtual returns (string memory) {
        return string(abi.encodePacked(baseMetadataURI, id.toDecimalString()));
    }
}
