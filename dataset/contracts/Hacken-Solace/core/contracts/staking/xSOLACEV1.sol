// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./../utils/Governable.sol";
import "./../interfaces/staking/IxSOLACEV1.sol";


/**
 * @title xSolace V1 Token (xSOLACE)
 * @author solace.fi
 * @notice V1 of the [**SOLACE**](./../SOLACE) staking contract.
 *
 * Users can stake their [**SOLACE**](./../SOLACE) and receive **xSOLACE**. **xSOLACE** is designed to be a safe up-only contract that allows users to enter or leave at any time. The value of **xSOLACE** relative to [**SOLACE**](./../SOLACE) will increase when [**SOLACE**](./../SOLACE) is sent to this contract, namely from premiums from coverage polices.
 *
 * Note that xSOLACEV1 was deprecated for the [new staking system](./xSOLACE).
 */
// solhint-disable-next-line contract-name-camelcase
contract xSOLACEV1 is IxSOLACEV1, ERC20Permit, ReentrancyGuard, Governable {
    using SafeERC20 for IERC20;
    using Address for address;

    address internal _solace;

    /**
     * @notice Constructs the **xSOLACE** Token contract.
     * @param governance_ The address of the [governor](/docs/protocol/governance).
     * @param solace_ Address of the [**SOLACE**](./../SOLACE) contract.
     */
    constructor(address governance_, address solace_) ERC20("xsolace", "xSOLACE") ERC20Permit("xsolace") Governable(governance_) {
        require(solace_ != address(0x0), "zero address solace");
        _solace = solace_;
    }

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /// @notice Address of the [**SOLACE**](./../SOLACE) contract.
    function solace() external view override returns (address solace_) {
        return _solace;
    }

    /**
     * @notice Determines the current value in **xSOLACE** for an amount of [**SOLACE**](./../SOLACE).
     * @param amountSolace The amount of [**SOLACE**](./../SOLACE).
     * @return amountXSolace The amount of **xSOLACE**.
     */
    function solaceToXSolace(uint256 amountSolace) public view override returns (uint256 amountXSolace) {
        uint256 s = IERC20(_solace).balanceOf(address(this));
        uint256 x = totalSupply();
        return (s == 0 || x == 0)
            ? amountSolace
            : ((x * amountSolace) / s);
    }

    /**
     * @notice Determines the current value in [**SOLACE**](./../SOLACE) for an amount of **xSOLACE**.
     * @param amountXSolace The amount of **xSOLACE**.
     * @return amountSolace The amount of [**SOLACE**](./../SOLACE).
     */
    function xSolaceToSolace(uint256 amountXSolace) public view override returns (uint256 amountSolace) {
        uint256 s = IERC20(_solace).balanceOf(address(this));
        uint256 x = totalSupply();
        return (s == 0 || x == 0)
            ? amountXSolace
            : ((s * amountXSolace) / x);
    }

    /***************************************
    MUTATOR FUNCTIONS
    ***************************************/

    /**
     * @notice Allows a user to stake [**SOLACE**](./../SOLACE).
     * Shares of the pool (xSOLACE) are minted to msg.sender.
     * @param amountSolace Amount of [**SOLACE**](./../SOLACE) to deposit.
     * @return amountXSolace The amount of **xSOLACE** minted.
     */
    function stake(uint256 amountSolace) external override nonReentrant returns (uint256 amountXSolace) {
        // pull solace
        SafeERC20.safeTransferFrom(IERC20(_solace), msg.sender, address(this), amountSolace);
        // accounting
        return _stake(msg.sender, amountSolace);
    }

    /**
     * @notice Allows a user to stake [**SOLACE**](./../SOLACE).
     * Shares of the pool (xSOLACE) are minted to msg.sender.
     * @param depositor The depositing user.
     * @param amountSolace The deposit amount.
     * @param deadline Time the transaction must go through before.
     * @param v secp256k1 signature
     * @param r secp256k1 signature
     * @param s secp256k1 signature
     * @return amountXSolace The amount of **xSOLACE** minted.
     */
    function stakeSigned(address depositor, uint256 amountSolace, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override nonReentrant returns (uint256 amountXSolace) {
        // permit
        IERC20Permit(_solace).permit(depositor, address(this), amountSolace, deadline, v, r, s);
        // pull solace
        SafeERC20.safeTransferFrom(IERC20(_solace), depositor, address(this), amountSolace);
        // accounting
        return _stake(depositor, amountSolace);
    }

    /**
     * @notice Allows a user to unstake **xSOLACE**.
     * Burns **xSOLACE** tokens and transfers [**SOLACE**](./../SOLACE) to msg.sender.
     * @param amountXSolace Amount of **xSOLACE**.
     * @return amountSolace Amount of [**SOLACE**](./../SOLACE) returned.
     */
    function unstake(uint256 amountXSolace) external override nonReentrant returns (uint256 amountSolace) {
        // burn xsolace
        _burn(msg.sender, amountXSolace);
        // accounting
        return _unstake(msg.sender, amountXSolace);
    }

    /**
     * @notice Burns **xSOLACE** from msg.sender.
     * @param amount Amount to burn.
     */
    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    /***************************************
    INTERNAL FUNCTIONS
    ***************************************/

    /**
     * @notice Handles minting of **xSOLACE** during deposit.
     * @param depositor The depositing user.
     * @param amountSolace The [**SOLACE**](./../SOLACE) deposit amount.
     * @return amountXSolace The amount of **xSOLACE** minted.
     */
    function _stake(address depositor, uint256 amountSolace) internal returns (uint256 amountXSolace) {
        uint256 s = IERC20(_solace).balanceOf(address(this)) - amountSolace; // solace already deposited
        uint256 x = totalSupply();
        amountXSolace = (s == 0 || x == 0)
            ? amountSolace
            : ((x * amountSolace) / s);
        _mint(depositor, amountXSolace);
        emit Staked(depositor, amountSolace, amountXSolace);
        return amountXSolace;
    }

    /**
     * @notice Handles burning of **xSOLACE** during deposit.
     * @param depositor The depositing user.
     * @param amountXSolace The **xSOLACE** deposit amount.
     * @return amountSolace The amount of [**SOLACE**](./../SOLACE) minted.
     */
    function _unstake(address depositor, uint256 amountXSolace) internal returns (uint256 amountSolace) {
        uint256 s = IERC20(_solace).balanceOf(address(this));
        uint256 x = totalSupply() + amountXSolace; // xsolace already burnt
        amountSolace = (s == 0 || x == 0)
            ? amountXSolace
            : ((s * amountXSolace) / x);
        SafeERC20.safeTransfer(IERC20(_solace), depositor, amountSolace);
        emit Unstaked(depositor, amountSolace, amountXSolace);
        return amountSolace;
    }
}
