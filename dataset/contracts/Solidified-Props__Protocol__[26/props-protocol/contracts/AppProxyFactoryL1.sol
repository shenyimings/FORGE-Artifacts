// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "./IAppProxyFactoryBridged.sol";
import "./tokens/app-points/IAppPoints.sol";
import "./utils/MinimalProxyFactory.sol";

/**
 * @title  AppProxyFactoryL1
 * @author Props
 * @dev    The L1 factory responsible for deploying new apps. When triggered,
 *         a deployment will create an AppPoints token on L1 but will, in turn,
 *         trigger a corresponding deployment on L2 via an L1 - L2 bridge.
 *         The L2 deployment is handled by the `AppProxyFactoryL2` contract.
 */
contract AppProxyFactoryL1 is Initializable, MinimalProxyFactory {
    /**************************************
                     FIELDS
    ***************************************/

    // The app proxy factory controller
    address public controller;

    // The Props protocol treasury address
    address public propsTreasury;

    // Logic contract for app points contract proxies
    address public appPointsLogic;

    // The bridge contract used to relay app deployments to L2
    address public appProxyFactoryBridge;

    /**************************************
                     EVENTS
    ***************************************/

    event AppDeployed(address indexed appPoints, string name, string symbol, address owner);

    /**************************************
                    MODIFIERS
    ***************************************/

    modifier only(address _account) {
        require(msg.sender == _account, "Unauthorized");
        _;
    }

    /***************************************
                   INITIALIZER
    ****************************************/

    /**
     * @dev Initializer.
     * @param _controller The app proxy factory controller
     * @param _propsTreasury The Props protocol treasury that a percentage of all minted app points will go to
     * @param _appPointsLogic The logic contract for app points contract proxies
     */
    function initialize(
        address _controller,
        address _propsTreasury,
        address _appPointsLogic
    ) public initializer {
        controller = _controller;
        propsTreasury = _propsTreasury;
        appPointsLogic = _appPointsLogic;
    }

    /***************************************
                CONTROLLER ACTIONS
    ****************************************/

    /**
     * @dev Transfer the control of the contract to a new address.
     * @param _controller The new controller
     */
    function transferControl(address _controller) external only(controller) {
        require(_controller != address(0), "Cannot be set to the zero address");
        controller = _controller;
    }

    /**
     * @dev Change the logic contract for app points contract proxies.
     * @param _appPointsLogic The address of the new logic contract
     */
    function changeAppPointsLogic(address _appPointsLogic) external only(controller) {
        appPointsLogic = _appPointsLogic;
    }

    /**
     * @dev Change the app deployment bridge contract.
     * @param _appProxyFactoryBridge The address of the new bridge contract
     */
    function changeAppProxyFactoryBridge(address _appProxyFactoryBridge) external only(controller) {
        appProxyFactoryBridge = _appProxyFactoryBridge;
    }

    /***************************************
                  USER ACTIONS
    ****************************************/

    /**
     * @dev Deploy a new app.
     * @param _name The name of the app
     * @param _symbol The symbol of the app
     * @param _amount The initial amount of app points to be minted
     * @param _owner The owner of the app
     * @param _dailyRewardEmission The daily reward emission parameter for the app points staking contract
     */
    function deployApp(
        string calldata _name,
        string calldata _symbol,
        uint256 _amount,
        address _owner,
        uint256 _dailyRewardEmission
    ) external {
        // Deploy the app points contract
        address appPointsProxy =
            deployMinimal(
                appPointsLogic,
                abi.encodeWithSignature(
                    "initialize(string,string,uint256,address,address)",
                    _name,
                    _symbol,
                    _amount,
                    _owner,
                    propsTreasury
                )
            );

        // Pause app points transfers
        IAppPoints(appPointsProxy).pause();

        // The app owner is whitelisted for app points transfers
        IAppPoints(appPointsProxy).updateTransferWhitelist(_owner, true);

        // Transfer ownership to the app owner
        OwnableUpgradeable(appPointsProxy).transferOwnership(_owner);

        // Trigger a corresponding L2 deployment
        IAppProxyFactoryBridged(appProxyFactoryBridge).deployApp(
            appPointsProxy,
            _name,
            _symbol,
            _owner,
            _dailyRewardEmission
        );

        emit AppDeployed(appPointsProxy, _name, _symbol, _owner);
    }
}
