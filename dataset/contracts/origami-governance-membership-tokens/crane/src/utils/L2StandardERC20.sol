// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IL2StandardERC20, ILegacyMintableERC20} from "src/interfaces/utils/IL2StandardERC20.sol";
import {ERC20Base} from "src/token/governance/ERC20Base.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";
import {ERC20Upgradeable} from "@oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/**
 * @title L2StandardERC20
 * @author Origami
 * @notice an ERC20 extension that is compatible with the Optimism bridge
 * @custom:security-contact contract-security@joinorigami.com
 */
contract L2StandardERC20 is ERC20Base, IL2StandardERC20 {
    bytes32 public constant L2BRIDGE_INFO_STORAGE_POSITION = keccak256("com.origami.l2bridge.info");

    /// @dev diamond storage for L2BridgeInfo so it's upgrade-compatible
    struct L2BridgeInfo {
        address l1Token;
        address l2Bridge;
    }

    /// @dev returns the storage pointer for the L2BridgeInfo struct
    function l2BridgeInfoStorage() internal pure returns (L2BridgeInfo storage l2bi) {
        bytes32 position = L2BRIDGE_INFO_STORAGE_POSITION;
        // solhint-disable no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            l2bi.slot := position
        }
        // solhint-enable no-inline-assembly
    }

    /// @inheritdoc ILegacyMintableERC20
    function l1Token() public view returns (address) {
        return l2BridgeInfoStorage().l1Token;
    }

    /// @inheritdoc IL2StandardERC20
    function l2Bridge() public view returns (address) {
        return l2BridgeInfoStorage().l2Bridge;
    }

    /**
     * @notice sets the address of the paired ERC20 token on L1
     * @param newL1Token address of the paired ERC20 token on L1
     */
    function setL1Token(address newL1Token) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address oldL1Token = l2BridgeInfoStorage().l1Token;
        require(newL1Token != oldL1Token, "L2StandardERC20: L1 token value must change");
        require(newL1Token != address(0), "L2StandardERC20: L1 token cannot be zero address");

        l2BridgeInfoStorage().l1Token = newL1Token;
        emit L1TokenUpdated(oldL1Token, newL1Token);
    }

    /**
     * @notice sets the address of the bridge contract on L2
     * @param newL2Bridge address of the bridge contract on L2
     */
    function setL2Bridge(address newL2Bridge) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address oldL2Bridge = l2BridgeInfoStorage().l2Bridge;

        require(newL2Bridge != oldL2Bridge, "L2StandardERC20: L2 bridge value must change");
        require(newL2Bridge != address(0), "L2StandardERC20: L2 bridge cannot be zero address");

        l2BridgeInfoStorage().l2Bridge = newL2Bridge;
        emit L2BridgeUpdated(oldL2Bridge, newL2Bridge);
    }

    /**
     * @notice returns true if the contract implements the interface defined by interfaceId
     * @param interfaceId bytes4 of the interface
     * @dev the IERC165 and ILegacyMintableERC20interfaces interfaces are critical for compatiblity with the OP bridge
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC20Base, IERC165) returns (bool) {
        return interfaceId == type(ILegacyMintableERC20).interfaceId || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IL2StandardERC20).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc ILegacyMintableERC20
    function mint(address account, uint256 amount)
        public
        virtual
        override(ERC20Base, ILegacyMintableERC20)
        onlyRole(MINTER_ROLE)
    {
        super._mint(account, amount);
        emit Mint(account, amount);
    }

    /// @inheritdoc ILegacyMintableERC20
    function burn(address account, uint256 amount) public virtual override onlyRole(BURNER_ROLE) {
        super._burn(account, amount);
        emit Burn(account, amount);
    }
}
