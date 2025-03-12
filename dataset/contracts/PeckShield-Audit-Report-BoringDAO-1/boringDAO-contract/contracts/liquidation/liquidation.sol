// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interface/IAddressResolver.sol";
import "../interface/IPause.sol";
import "../interface/ILiquidate.sol";

interface IHasRole {
    function hashRole(bytes32 role, address account) external view returns (bool);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}

contract Liquidation is AccessControl {

    using SafeMath for uint;

    bytes32 public constant TRUSTEE_ROLE = "TRUSTEE_ROLE";
    bytes32 public constant BORING_DAO = "BoringDAO";
    bytes32 public constant OBTC = "oBTC";
    address public coreDev;

    bool public shouldPauseDev;
    bool public shouldPauseTrustee;
    bool public systemPause;

    IAddressResolver public addressReso;

    mapping(address => bool) public isSatellitePool;

    mapping(address=>mapping(address=>mapping(address=>bool))) public confirm;
    mapping(address=>mapping(address=>uint)) public confirmCount;

    mapping(address=>mapping(address=>bool)) public unpauseConfirm;
    mapping(address=>uint) public unpausePoolConfirmCount;

    constructor(address _coreDev, address _addressReso) public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        coreDev = _coreDev;
        addressReso = IAddressResolver(_addressReso);
    }

    function boringDAO() internal view returns (IPause) {
        return IPause(addressReso.requireAndKey2Address(BORING_DAO, "Liquidation::boringDAO contract not exist"));
    }

    function otoken() internal view returns (IPause) {
        return IPause(addressReso.requireAndKey2Address(OBTC, "Liquidation::oBTC contract not exist"));
    }

    function setIsSatellitePool(address pool, bool state) public {
        require(msg.sender == coreDev, "Liquidation::setIsSatellitePool:caller is not coreDev");
        if(isSatellitePool[pool] != state) {
            isSatellitePool[pool] = state;
        }
    }

    // will pause the system
    function pause(address[] memory pools) public onlyPauser {
        if (msg.sender == coreDev) {
            shouldPauseDev = true;
        } else {
            shouldPauseTrustee = true;
        }
        if (shouldPauseDev && shouldPauseTrustee) {
            systemPause = true;
            // pause the system
            boringDAO().pause();
            // pause satellitepool
            for(uint i=0; i < pools.length; i++) {
                if(isSatellitePool[pools[i]] == true) {
                    IPause(pools[i]).pause();
                }
            }
        }
    }

    function unpause() public onlyPauser {
        require(systemPause == true, "Liquidation::unpause:should paused when call unpause()");
        if (msg.sender == coreDev) {
            shouldPauseDev = false;
        } else {
            shouldPauseTrustee = false;
        }
        if (shouldPauseDev != true && shouldPauseTrustee != true) {
            systemPause = false;
            boringDAO().unpause();
        }
    }

    // unpause satellitepool before unpause()
    function unpauseSatellitePool(address pool) public onlyTrustee {
        require(systemPause == true, "Liquidation::unpauseSatellitePool:systemPause should paused when call unpause()");
        require(isSatellitePool[pool] == true, "Liquidation::unpauseSatellitePool:Not SatellitePool");
        if(unpauseConfirm[msg.sender][pool] == false) {
            unpauseConfirm[msg.sender][pool] = true;
            unpausePoolConfirmCount[pool] = unpausePoolConfirmCount[pool].add(1);
        }
        uint trusteeCount = IHasRole(addressReso.requireAndKey2Address(BORING_DAO, "Liquidation::withdraw: boringDAO contract not exist")).getRoleMemberCount(TRUSTEE_ROLE);
        uint threshold = trusteeCount.mod(3) == 0 ? trusteeCount.mul(2).div(3) : trusteeCount.mul(2).div(3).add(1);
        if (unpausePoolConfirmCount[pool] >= threshold) {
            IPause(pool).unpause();
        }
    }

    function confirmWithdraw(address target, address to) public onlyTrustee {
        if(systemPause == true && confirm[msg.sender][target][to] == false) {
            confirm[msg.sender][target][to] = true;
            confirmCount[target][to] = confirmCount[target][to].add(1);
        }
    }

    function withdraw(address target, address to) public onlyPauser {
        require(systemPause == true, "Liquidation::withdraw:system not pause");
        require(isSatellitePool[target] == true, "Liquidation::withdraw:Not SatellitePool or tunnel");
        uint trusteeCount = IHasRole(addressReso.requireAndKey2Address(BORING_DAO, "Liquidation::withdraw: boringDAO contract not exist")).getRoleMemberCount(TRUSTEE_ROLE);
        uint threshold = trusteeCount.mod(3) == 0 ? trusteeCount.mul(2).div(3) : trusteeCount.mul(2).div(3).add(1);
        if (confirmCount[target][to] >= threshold) {
            ILiquidate(target).liquidate(to);
        }
    }


    modifier onlyPauser {
        require(msg.sender == coreDev || IHasRole(address(boringDAO())).hashRole(TRUSTEE_ROLE, msg.sender), "caller is not a pauser");
        _;
    }

    modifier onlyTrustee {
        require(IHasRole(address(boringDAO())).hashRole(TRUSTEE_ROLE, msg.sender), "caller is not a trustee");
        _;
    }
}