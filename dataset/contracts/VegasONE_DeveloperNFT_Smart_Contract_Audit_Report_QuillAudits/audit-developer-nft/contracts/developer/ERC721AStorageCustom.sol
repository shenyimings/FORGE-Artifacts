// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

library ERC721AStorageCustom {
    struct Level {
        uint256 price;
        // maximum agent amount
        uint256 maxAgentAmount;
    }

    struct Token {
        uint256 level;
        uint256 levelVersion;
    }

    struct TokenWithLevel {
        uint256 tokenId;
        uint256 levelNum;
        Level level;
    }

    struct Layout {
        // all periods sum up
        uint256 _sumOfPeriodTokenSupply;
        // number of sold tokens by level
        mapping(uint256 => uint256) _soldTokenAmount;
        // token supply of current period
        uint256 _periodTokenSupply;
        // signer who authorize mint (backend)
        address _signerAddress;
        // paytment token
        address _paymentContract;
        // record used uuid
        mapping(string => bool) _usedUUID;
        // record current level version
        uint256 _levelVersion;
        // record level info by version
        mapping(uint256 => Level[]) _levels;
        // record each level is mintable or not
        mapping(uint256 => bool) _mintable;
        // record each level's maximum supply
        mapping(uint256 => uint256) _levelTokenSupply;
        // sum up of all level's supply
        uint256 _sumOfLevelTokenSupply;
        // each tokenId matching with level
        mapping(uint256 => Token) _tokenLevel;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("ERC721A.contracts.customStorage.ERC721A");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
