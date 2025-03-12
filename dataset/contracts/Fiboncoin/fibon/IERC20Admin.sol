
pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Admin {

    function upgradeIcoStage() external returns (bool);

    function setProxyContract(address proxyContract) external returns (bool);

    function burn(address account, uint256 amount) external returns (bool);

    function earlyBackerTransfer(address recipient, uint256 amount) external returns (bool);

    function icoTransfer(address recipient, uint256 amount) external returns (bool);

   
}