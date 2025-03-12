// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./IPropsProtocol.sol";
import "./staking/IStaking.sol";
import "./tokens/app-points/IAppPoints.sol";
import "./utils/MinimalProxyFactory.sol";

/**
 * @title  AppProxyFactoryL2
 * @author Props
 * @dev    The L2 factory responsible for deploying new apps. An L2 app
 *         deployment can only be triggered via the L1 - L2 bridge, as a
 *         result of a corresponding L1 deployment.
 */
contract AppProxyFactoryL2 is Initializable, MinimalProxyFactory {
    /**************************************
                     FIELDS
    ***************************************/

    // The app proxy factory controller
    address public controller;

    // The PropsProtocol contract
    address public propsProtocol;

    // Props protocol related tokens
    address public propsToken;

    // Logic contract for app points contract proxies
    address public appPointsLogic;
    // Logic contract for app points staking contract proxies
    address public appPointsStakingLogic;

    // The bridge contract used to relay app deployments from L1
    address public appProxyFactoryBridge;

    /**************************************
                     EVENTS
    ***************************************/

    event AppDeployed(
        address indexed l1AppPoints,
        address indexed appPoints,
        address indexed appPointsStaking,
        string name,
        string symbol,
        address owner
    );

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
     * @param _propsProtocol The PropsProtocol contract
     * @param _propsToken The Props token contract
     * @param _appPointsLogic The logic contract for app points contract proxies
     * @param _appPointsStakingLogic The logic contract for app points staking contract proxies
     */
    function initialize(
        address _controller,
        address _propsProtocol,
        address _propsToken,
        address _appPointsLogic,
        address _appPointsStakingLogic
    ) public initializer {
        controller = _controller;
        propsProtocol = _propsProtocol;
        propsToken = _propsToken;
        appPointsLogic = _appPointsLogic;
        appPointsStakingLogic = _appPointsStakingLogic;
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
     * @dev Change the logic contract for app points staking contract proxies.
     * @param _appPointsStakingLogic The address of the new logic contract
     */
    function changeAppPointsStakingLogic(address _appPointsStakingLogic) external only(controller) {
        appPointsStakingLogic = _appPointsStakingLogic;
    }

    /**
     * @dev Change the app deployment bridge contract.
     * @param _appProxyFactoryBridge The address of the new bridge contract
     */
    function changeAppProxyFactoryBridge(address _appProxyFactoryBridge) external only(controller) {
        appProxyFactoryBridge = _appProxyFactoryBridge;
    }

    /***************************************
                 BRIDGE ACTIONS
    ****************************************/

    /**
     * @dev Deploy a new app.
     * @param _l1AppPoints The address of the corresponding L1 AppPoints token contract
     * @param _name The name of the app
     * @param _symbol The symbol of the app
     * @param _owner The owner of the app
     * @param _dailyRewardEmission The daily reward emission parameter for the app points staking contract
     */
    function deployApp(
        address _l1AppPoints,
        string calldata _name,
        string calldata _symbol,
        address _owner,
        uint256 _dailyRewardEmission
    ) external only(appProxyFactoryBridge) {
        // Deploy the app points contract
        address appPointsProxy =
            deployMinimal(
                appPointsLogic,
                abi.encodeWithSignature("initialize(string,string)", _name, _symbol)
            );

        // Deploy the corresponding staking contract for the app points
        address appPointsStakingProxy =
            deployMinimal(
                appPointsStakingLogic,
                abi.encodeWithSignature(
                    "initialize(address,address,address,uint256)",
                    propsProtocol,
                    _owner,
                    appPointsProxy,
                    _dailyRewardEmission
                )
            );

        // Pause app points transfers
        IAppPoints(appPointsProxy).pause();

        // The following addresses are whitelisted for app points transfers:
        // - the app owner
        // - the PropsProtocol contract
        // - the app points staking contract
        IAppPoints(appPointsProxy).updateTransferWhitelist(_owner, true);
        IAppPoints(appPointsProxy).updateTransferWhitelist(propsProtocol, true);
        IAppPoints(appPointsProxy).updateTransferWhitelist(appPointsStakingProxy, true);

        // Transfer ownership to the app owner
        OwnableUpgradeable(appPointsProxy).transferOwnership(_owner);

        // Integrate the app within the Props protocol
        IPropsProtocol(propsProtocol).saveApp(appPointsProxy, appPointsStakingProxy);

        emit AppDeployed(
            _l1AppPoints,
            appPointsProxy,
            appPointsStakingProxy,
            _name,
            _symbol,
            _owner
        );
    }
}
