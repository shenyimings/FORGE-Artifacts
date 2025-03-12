// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20Upgradeable, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../libraries/DelegateCallAware.sol";
import {AlreadyInit, HadZeroInit} from "../libraries/Error.sol";
import "./IGasToken.sol";

contract GasToken is Initializable, DelegateCallAware, ERC20Upgradeable, IGasToken {
    /**
     * @notice Emitted whenever tokens are minted for an account.
     *
     * @param account Address of the account tokens are being minted for.
     * @param amount  Amount of tokens minted.
     */
    event Mint(address indexed account, uint256 amount);

    /**
     * @notice Emitted whenever tokens are burned from an account.
     *
     * @param account Address of the account tokens are being burned from.
     * @param amount  Amount of tokens burned.
     */
    event Burn(address indexed account, uint256 amount);

    address public BRIDGE;
    address public INBOX;

    /**
     * @notice A modifier that only allows the bridge to call
     */
    modifier onlyBridge() {
        require(msg.sender == BRIDGE, "GasToken: only bridge can mint");
        _;
    }
    /**
     * @notice A modifier that only allows the bridge to call
     */
    modifier onlyInbox() {
        require(msg.sender == INBOX, "GasToken: only inbox can burn");
        _;
    }

    function initialize(
        address _bridge,
        address _inbox,
        address _to,
        uint256 _amount
    ) external initializer onlyDelegated {
        if (_bridge == address(0)) revert HadZeroInit();
        if (BRIDGE != address(0)) revert AlreadyInit();
        BRIDGE = _bridge;
        
        if (_inbox == address(0)) revert HadZeroInit();
        if (INBOX != address(0)) revert AlreadyInit();
        INBOX = _inbox;

        __ERC20_init("US Nativ3 Token", "USNT");
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    /**
     * @notice Allows the StandardBridge on this network to mint tokens.
     *
     * @param _to     Address to mint tokens to.
     * @param _amount Amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external virtual onlyBridge {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    /**
     * @notice Allows the StandardBridge on this network to burn tokens.
     *
     * @param _from   Address to burn tokens from.
     * @param _amount Amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) external virtual onlyInbox {
        _burn(_from, _amount);
        emit Burn(_from, _amount);
    }

    /**
     * @notice ERC165 interface check function.
     *
     * @param _interfaceId Interface ID to check.
     *
     * @return Whether or not the interface is supported by this contract.
     */
    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        bytes4 iface1 = type(IERC165).interfaceId;
        // Interface corresponding to the legacy L2StandardERC20.
        bytes4 iface2 = type(IERC20Upgradeable).interfaceId;
        return _interfaceId == iface1 || _interfaceId == iface2;
    }
}
