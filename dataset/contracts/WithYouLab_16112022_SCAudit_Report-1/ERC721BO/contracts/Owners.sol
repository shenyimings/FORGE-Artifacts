// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Library for owner list using delayed initialization mechanism.
 */
library Owners {
    struct AddressSet {
        mapping(uint256 => uint256) _inner;
    }

    /**
     * @dev Returns the owner of `tokenId`.
     */
    function ownerOf(AddressSet storage set, uint256 tokenId) internal view returns (address) {
        unchecked{
            uint256 i = tokenId;
            do {
                (address o, uint256 c) = unpack(set._inner[i]);
                if (o != address(0) && i + c > tokenId){
                    return o;
                }
                --i;
            } while (i != type(uint256).max);

            return address(0);
        }
    }

    /**
     * @dev Set `from` to `from + count` as tokens owned by the `owner`.
     */
    function mint(AddressSet storage set, address owner, uint256 from, uint256 count) internal {
        set._inner[from] = pack(owner, count);
    }

    /**
     * @dev Change the owner of `tokenId` to `owner`.
     */
    function overwrite(AddressSet storage set, uint256 tokenId, address owner) internal {
        (address o, uint256 c) = unpack(set._inner[tokenId]);
        set._inner[tokenId] = pack(owner, 1);
        if (o == address(0) || c <= 1)
            return;

        uint256 nextTokenId = tokenId + 1;
        if (unpackAddress(set._inner[nextTokenId]) == address(0))
            set._inner[nextTokenId] = pack(o, c - 1);
    }

    /**
     * @dev Returns the value of `owner` and `count` packed into a uint256 value.
     */
    function pack(address owner, uint256 count) private pure returns (uint256){
        require(type(uint32).max >= count, "ERC721BO Owners: count must be less than 2^32");
        // Unchecked because bitwise operations only.
        unchecked {
            return (uint256(uint160(owner)) << 32) | count;
        }
    }

    /**
     * @dev Returns `owner` and `count` from `packed`.
     */
    function unpack(uint256 packed) private pure returns (address owner, uint256 count){
        // Unchecked because bitwise operations only.
        unchecked {
            owner = address(uint160(packed >> 32));
            count = packed & type(uint32).max;
        }
    }

    /**
     * @dev Returns owner address from `packed`.
     */
    function unpackAddress(uint256 packed) private pure returns (address){
        // Unchecked because bitwise operations only.
        unchecked {
            return address(uint160(packed >> 32) & type(uint160).max);
        }
    }
}
