// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import { IERC20 } from "@oz/token/ERC20/IERC20.sol";
import { Ownable } from "@oz/access/Ownable.sol";
import { Clones } from "@oz/proxy/Clones.sol";
import { IERC20Metadata } from "@oz/token/ERC20/extensions/IERC20Metadata.sol";
import { Errors } from "./errors/Errors.sol";
import { IArena, Fee, Outcome, BattleKey, CreateBattleParams } from "./interfaces/IArena.sol";
import { IBattleInit } from "./interfaces/battle/IBattleInit.sol";
import { IBattleState } from "./interfaces/battle/IBattleState.sol";
import { IBattleActions, IBattleMintBurn } from "./interfaces/battle/IBattleActions.sol";
import { DeploymentParams } from "./params/DeploymentParams.sol";
import { SToken } from "./token/SToken.sol";
import { getAdjustPrice } from "./utils.sol";

/// @notice Deploys battles. Sets pool underlying, collateral, fees and other
/// deployment
/// parameters.
contract Arena is IArena, Ownable {
    address public oracleAddr;
    address[] private battleList;
    address public battleImpl;
    bool public isPermissionless;
    DeploymentParams public deploymentParameters;
    mapping(bytes32 => address) public battles;
    mapping(string => Fee) public fees;
    // mapping(address => mapping(string => bool)) public isSupported;

    mapping(address => bool) public collateralWhitelist;
    mapping(string => bool) public underlyingWhitelist;

    constructor(address _oracleAddr, address _battleImpl) {
        oracleAddr = _oracleAddr;
        battleImpl = _battleImpl;
    }

    function setFeeForUnderlying(string calldata underlying, Fee calldata _fee) external onlyOwner {
        fees[underlying] = _fee;
    }

    event CollateralWhitelistChanged(address collateral, bool state);

    function setCollateralWhitelist(address collateral, bool isSupported) external onlyOwner {
        require(collateralWhitelist[collateral] != isSupported, "LD");
        collateralWhitelist[collateral] = isSupported;
        emit CollateralWhitelistChanged(collateral, isSupported);
    }

    event UnderlyingWhitelistChanged(string underlying, bool state, Fee fee);

    function setUnderlyingWhitelist(string memory underlying, bool isSupported, Fee calldata fee) external onlyOwner {
        require(underlyingWhitelist[underlying] != isSupported, "LD");
        underlyingWhitelist[underlying] = isSupported;
        fees[underlying] = fee;
        emit UnderlyingWhitelistChanged(underlying, isSupported, fee);
    }

    event PermissionlessChanged(bool state);

    function setPermissionless() external onlyOwner {
        isPermissionless = !isPermissionless;
        emit PermissionlessChanged(isPermissionless);
    }

    function createBattle(BattleKey memory bk) external override returns (address battle) {
        // collaterl address error
        if (bk.collateral == address(0)) {
            revert Errors.ZeroAddress();
        }

        // not supported
        if (!isPermissionless) {
            if (!collateralWhitelist[bk.collateral]) {
                revert Errors.NotSupported();
            }
        }

        if (!underlyingWhitelist[bk.underlying]) {
            revert Errors.NotSupported();
        }

        // expiries must at 8am utc
        if ((bk.expiries - 28_800) % 86_400 != 0 || block.timestamp >= bk.expiries) {
            revert Errors.NotSupportedExpiries();
        }

        bk.strikeValue = getAdjustPrice(bk.strikeValue);
        bytes32 battleKeyB32 = keccak256(abi.encode(bk.collateral, bk.underlying, bk.expiries, bk.strikeValue));
        if (battles[battleKeyB32] != address(0)) {
            revert Errors.BattleExisted();
        }
        deploymentParameters = DeploymentParams({
            arenaAddr: address(this),
            battleKey: bk,
            oracleAddr: oracleAddr,
            fee: fees[bk.underlying],
            spear: address(0),
            shield: address(0)
        });
        battle = Clones.cloneDeterministic(battleImpl, battleKeyB32);
        uint8 decimals = IERC20Metadata(bk.collateral).decimals();
        address spear = address(new SToken("Spear", "SPEAR", decimals, battle));
        address shield = address(new SToken("Shield", "SHIELD", decimals, battle));
        deploymentParameters.spear = spear;
        deploymentParameters.shield = shield;
        battles[battleKeyB32] = battle;
        battleList.push(battle);
        IBattleInit(battle).initState(deploymentParameters);
        emit BattleCreated(bk, battle, spear, shield, fees[bk.underlying]);
    }

    function getBattle(BattleKey memory battleKey) external view override returns (address battle) {
        battleKey.strikeValue = getAdjustPrice(battleKey.strikeValue);
        bytes32 battleKeyB32 = keccak256(abi.encode(battleKey.collateral, battleKey.underlying, battleKey.expiries, battleKey.strikeValue));
        battle = battles[battleKeyB32];
    }

    function getAllBattles() external view override returns (BattleInfo[] memory) {
        uint256 len = battleList.length;
        BattleInfo[] memory infos = new BattleInfo[](len);
        for (uint256 i; i < len; i++) {
            address battle = battleList[i];
            BattleKey memory bk = IBattleState(battle).battleKey();
            (uint160 sqrtPriceX96, int24 tick,) = IBattleState(battle).slot0();
            (uint256 startTS, uint256 endTS) = IBattleState(battle).startAndEndTS();
            (address spear, address shield) = IBattleState(battle).spearAndShield();
            Outcome result = IBattleState(battle).battleOutcome();
            infos[i] = BattleInfo({
                battle: battle,
                bk: bk,
                sqrtPriceX96: sqrtPriceX96,
                tick: tick,
                startTS: startTS,
                endTS: endTS,
                spear: spear,
                shield: shield,
                spearBalance: 0,
                shieldBalance: 0,
                result: result
            });
        }
        return infos;
    }
}
