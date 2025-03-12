// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Library for ownership flag table.
 */
library Assets {
    struct Pages {
        mapping(uint256 => uint256) _inner;
    }

    /**
     * @dev Returns page key by `pageNo` and `owner`.
     */
    function getPageKeyBy(uint256 pageNo, address owner) internal pure returns (uint256) {
        require(type(uint32).max >= pageNo, "ERC721BO Assets: pageNo must be less than 2^32");
        unchecked {
            return (uint256(uint160(owner)) << 32) | uint32(pageNo);
        }
    }

    /**
     * @dev Returns ownership flags by `owner` and `pageNo`.
     */
    function page(Pages storage pages, address owner, uint256 pageNo) internal view returns (uint256) {
        return pages._inner[getPageKeyBy(pageNo, owner)];
    }

    /**
     * @dev Returns whether the `owner` owns the `tokenId`.
     * Returns true if owned, false otherwise.
     */
    function exists(Pages storage pages, address owner, uint256 tokenId) internal view returns (bool) {
        unchecked {
            uint256 key = getPageKeyBy(tokenId >> 8, owner);
            return (pages._inner[key] >> (tokenId & 0xFF)) & 1 == 1;
        }
    }

    /**
     * @dev Set the ownership flag of the `tokenId` of `from` to false and the ownership flag of `to` to true.
     */
    function transfer(Pages storage pages, address from, address to, uint256 tokenId) internal {
        unset(pages, from, tokenId);
        set(pages, to, tokenId);
    }

    /**
     * @dev Set the ownership flag of the `tokenId` of `owner` to true.
     */
    function set(Pages storage pages, address owner, uint256 tokenId) internal {
        unchecked {
            uint256 key = getPageKeyBy(tokenId >> 8, owner);
            pages._inner[key] |= (1 << (tokenId & 0xFF));
        }
    }

    /**
     * @dev Override the ownership flag of `owner` from `from` to `from` + `count` with true.
     */
    function setRange(Pages storage pages, address owner, uint256 from, uint256 count) internal {
        if (count == 0)
            return;

        uint256 to = from + count - 1;
        uint256 fromPageNo = from >> 8;
        uint256 toPageNo = to >> 8;

        unchecked {
            if (fromPageNo != toPageNo)
            {
                uint256 fromPage = getPageKeyBy(fromPageNo, owner);
                uint256 toPage = getPageKeyBy(toPageNo, owner);

                uint256 i = fromPage;
                do {
                    uint256 mask = type(uint256).max;
                    if (i == toPage)
                        mask >>= 0xFF - (to & 0xFF);

                    if (i == fromPage)
                        mask -= (1 << (from & 0xFF)) - 1;

                    pages._inner[i] |= mask;
                    ++i;
                } while (i <= toPage);
            }
            else{
                uint256 mask = type(uint256).max;
                mask >>= 0xFF - (to & 0xFF);
                mask -= (1 << (from & 0xFF)) - 1;
                pages._inner[getPageKeyBy(fromPageNo, owner)] |= mask;
            }
        }
    }

    /**
     * @dev Set the ownership flag of the `tokenId` of `owner` to false.
     */
    function unset(Pages storage pages, address owner, uint256 tokenId) internal {
        unchecked {
            uint256 key = getPageKeyBy(tokenId >> 8, owner);
            pages._inner[key] &= ~(1 << (tokenId & 0xFF));
        }
    }

    /**
     * @dev Override the ownership flag of `owner` from `from` to `from` + `count` with false.
     */
    function unsetRange(Pages storage pages, address owner, uint256 from, uint256 count) internal {
        if (count == 0)
            return;

        uint256 to = from + count - 1;
        uint256 fromPageNo = from >> 8;
        uint256 toPageNo = to >> 8;

        unchecked {
            if (fromPageNo != toPageNo)
            {
                uint256 fromPage = getPageKeyBy(fromPageNo, owner);
                uint256 toPage = getPageKeyBy(toPageNo, owner);

                uint256 i = fromPage;
                do {
                    uint256 mask = type(uint256).max;
                    if (i == toPage)
                        mask >>= 0xFF - (to & 0xFF);

                    if (i == fromPage)
                        mask -= (1 << (from & 0xFF)) - 1;

                    pages._inner[i] &= ~mask;
                    ++i;
                } while (i <= toPage);
            }
            else{
                uint256 mask = type(uint256).max;
                mask >>= 0xFF - (to & 0xFF);
                mask -= (1 << (from & 0xFF)) - 1;
                pages._inner[getPageKeyBy(fromPageNo, owner)] &= ~mask;
            }
        }
    }
}
