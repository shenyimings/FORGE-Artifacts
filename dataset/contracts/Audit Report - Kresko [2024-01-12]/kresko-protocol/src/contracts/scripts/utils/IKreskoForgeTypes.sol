// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {MockERC20} from "mocks/MockERC20.sol";
import {IAggregatorV3} from "kresko-lib/vendor/IAggregatorV3.sol";
import {IERC20} from "kresko-lib/token/IERC20.sol";
import {KreskoAsset} from "kresko-asset/KreskoAsset.sol";
import {KreskoAssetAnchor} from "kresko-asset/KreskoAssetAnchor.sol";
import {MockOracle} from "mocks/MockOracle.sol";
import {Asset} from "common/Types.sol";
import {Vault} from "vault/Vault.sol";
import {KISS} from "kiss/KISS.sol";
import {Deployment} from "factory/IDeploymentFactory.sol";
import {ERC20} from "kresko-lib/token/ERC20.sol";

interface IKreskoForgeTypes {
    struct AssetType {
        bool krAsset;
        bool collateral;
        bool scdpKrAsset;
        bool scdpDepositable;
    }
    struct CoreConfig {
        uint32 minterMcr;
        uint32 minterLt;
        uint32 scdpMcr;
        uint32 scdpLt;
        uint32 staleTime;
        uint8 sdiPrecision;
        uint8 oraclePrecision; // @note deprecated, removed soon
        address admin;
        address seqFeed;
        address council; // needs to be a contraaact
        address treasury;
    }

    struct KrAssetDeployInfo {
        address addr;
        string symbol;
        KreskoAsset krAsset;
        KreskoAssetAnchor anchor;
        Deployment krAssetProxy;
        Deployment anchorProxy;
        string anchorSymbol;
        address underlyingAddr;
    }

    struct ExtAssetInfo {
        address addr;
        string symbol;
        Asset config;
        IAggregatorV3 feed;
        address feedAddr;
        ERC20 token;
    }

    struct KrAssetInfo {
        address addr;
        string symbol;
        Asset config;
        KreskoAsset krAsset;
        KreskoAssetAnchor anchor;
        string anchorSymbol;
        address underlyingAddr;
        address feedAddr;
        MockOracle mockFeed;
        IAggregatorV3 feed;
        Deployment krAssetProxy;
        Deployment anchorProxy;
        IERC20 asToken;
    }
    struct MockConfig {
        string symbol;
        uint256 price;
        uint8 dec;
        uint8 feedDec;
        bool setFeeds;
    }

    struct MockTokenInfo {
        address addr;
        string symbol;
        Asset config;
        IAggregatorV3 feed;
        address feedAddr;
        MockERC20 mock;
        MockOracle mockFeed;
        IERC20 asToken;
    }
    struct KISSInfo {
        address addr;
        KISS kiss;
        Asset config;
        Vault vault;
        Deployment proxy;
        address vaultAddr;
        IERC20 asToken;
    }
}
