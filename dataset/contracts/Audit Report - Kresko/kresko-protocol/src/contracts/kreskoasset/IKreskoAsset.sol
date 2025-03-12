// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {IAccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";
import {IERC20Permit} from "../shared/IERC20Permit.sol";
import {IERC165} from "../shared/IERC165.sol";

interface IKreskoAsset is IERC20Permit, IAccessControlEnumerableUpgradeable, IERC165 {
    /**
     * @notice Rebase information
     * @param positive supply increasing/reducing rebase
     * @param denominator the denumerator for the operator, 1 ether = 1
     */
    struct Rebase {
        bool positive;
        uint256 denominator;
    }

    /**
     * @notice Initializes a KreskoAsset ERC20 token.
     * @dev Intended to be operated by the Kresko smart contract.
     * @param _name The name of the KreskoAsset.
     * @param _symbol The symbol of the KreskoAsset.
     * @param _decimals Decimals for the asset.
     * @param _admin The adminstrator of this contract.
     * @param _kresko The protocol, can perform mint and burn.
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _admin,
        address _kresko
    ) external;

    function kresko() external view returns (address);

    function rebaseInfo() external view returns (Rebase memory);

    function isRebased() external view returns (bool);

    /**
     * @notice Perform a rebase, changing the denumerator and its operator
     * @param _denominator the denumerator for the operator, 1 ether = 1
     * @param _positive supply increasing/reducing rebase
     * @param _pools UniswapV2Pair address to sync so we wont get rekt by skim() calls.
     * @dev denumerator values 0 and 1 ether will disable the rebase
     */
    function rebase(uint256 _denominator, bool _positive, address[] calldata _pools) external;

    /**
     * @notice Updates ERC20 metadata for the token in case eg. a ticker change
     * @param _name new name for the asset
     * @param _symbol new symbol for the asset
     * @param _version number that must be greater than latest emitted `Initialized` version
     */
    function reinitializeERC20(string memory _name, string memory _symbol, uint8 _version) external;

    /**
     * @notice Returns the total supply of the token.
     * @notice This amount is adjusted by rebases.
     * @inheritdoc IERC20Permit
     */
    function totalSupply() external view override(IERC20Permit) returns (uint256);

    /**
     * @notice Returns the balance of @param _account
     * @notice This amount is adjusted by rebases.
     * @inheritdoc IERC20Permit
     */
    function balanceOf(address _account) external view override(IERC20Permit) returns (uint256);

    /// @inheritdoc IERC20Permit
    function allowance(address _owner, address _account) external view override(IERC20Permit) returns (uint256);

    /// @inheritdoc IERC20Permit
    function approve(address spender, uint256 amount) external override returns (bool);

    /// @inheritdoc IERC20Permit
    function transfer(address _to, uint256 _amount) external override(IERC20Permit) returns (bool);

    /// @inheritdoc IERC20Permit
    function transferFrom(address _from, address _to, uint256 _amount) external override(IERC20Permit) returns (bool);

    /**
     * @notice Mints tokens to an address.
     * @dev Only callable by operator.
     * @dev Internal balances are always unrebased, events emitted are not.
     * @param _to The address to mint tokens to.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external;

    /**
     * @notice Burns tokens from an address.
     * @dev Only callable by operator.
     * @dev Internal balances are always unrebased, events emitted are not.
     * @param _from The address to burn tokens from.
     * @param _amount The amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) external;
}
