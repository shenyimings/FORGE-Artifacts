// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/*
 ██████╗ █████╗ ██╗   ██╗██╗        ██████╗ █████╗ ██╗     ██╗██████╗ ██╗████████╗██╗   ██╗
██╔════╝██╔══██╗██║   ██║██║       ██╔════╝██╔══██╗██║     ██║██╔══██╗██║╚══██╔══╝╚██╗ ██╔╝
╚█████╗ ██║  ██║██║   ██║██║       ╚█████╗ ██║  ██║██║     ██║██║  ██║██║   ██║    ╚████╔╝ 
 ╚═══██╗██║  ██║██║   ██║██║        ╚═══██╗██║  ██║██║     ██║██║  ██║██║   ██║     ╚██╔╝  
██████╔╝╚█████╔╝╚██████╔╝███████╗  ██████╔╝╚█████╔╝███████╗██║██████╔╝██║   ██║      ██║   
╚═════╝  ╚════╝  ╚═════╝ ╚══════╝  ╚═════╝  ╚════╝ ╚══════╝╚═╝╚═════╝ ╚═╝   ╚═╝      ╚═╝   

 * Twitter: https://twitter.com/SoulSolidity
 *  GitHub: https://github.com/SoulSolidity
 *     Web: https://SoulSolidity.com
 */

/// -----------------------------------------------------------------------
/// Package Imports (alphabetical)
/// -----------------------------------------------------------------------
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// -----------------------------------------------------------------------
/// Local Imports (alphabetical)
/// -----------------------------------------------------------------------
import {ICustomBillRefillable} from "./lib/ICustomBillRefillable.sol";
import {SoulAccessManaged} from "../../access/SoulAccessManaged.sol";
import {SoulZap_UniV2} from "../../SoulZap_UniV2.sol";

/// @title Role Setup Requirements for SoulZap Extension Bond NFT Whitelist
/// @notice This contract extension requires specific role setup to manage the whitelist of Bond NFTs.
/// The roles are managed through the SoulAccessManaged contract and are critical for the
/// security and proper administration of the whitelist functionality.
abstract contract SoulZap_Ext_BondNftWhitelist is SoulAccessManaged {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _whitelistedBondNfts;

    event BondNftWhitelisted(address indexed bondNft, bool whitelisted);

    /// @notice Add or remove a bondNft from the whitelist
    /// @param _bondNft The address of the bondNft to be added or removed
    /// @param _isWhitelisted True to add the bondNft to the whitelist, false to remove it
    function setBondNftWhitelist(
        address _bondNft,
        bool _isWhitelisted
    ) external onlyAccessRegistryRoleName("SOUL_ZAP_ADMIN_ROLE") {
        if (_isWhitelisted) {
            require(_whitelistedBondNfts.add(_bondNft), "BondNft already whitelisted");
            emit BondNftWhitelisted(_bondNft, true);
        } else {
            require(_whitelistedBondNfts.remove(_bondNft), "BondNft not whitelisted");
            emit BondNftWhitelisted(_bondNft, false);
        }
    }

    /// @notice Check if a bondNft is whitelisted
    /// @param _bond The bondNft to check
    /// @return True if the bondNft is whitelisted, false otherwise
    function isBondNftWhitelisted(ICustomBillRefillable _bond) public view returns (bool) {
        return _whitelistedBondNfts.contains(_bond.billNft());
    }

    /// @notice Get the count of whitelisted bondNfts
    /// @return The number of whitelisted bondNfts
    function getWhitelistedBondNftCount() public view returns (uint256) {
        return _whitelistedBondNfts.length();
    }

    /// @notice Get a whitelisted bondNft by index
    /// @param _index The index of the whitelisted bondNft
    /// @return The address of the whitelisted bondNft at the given index
    function getWhitelistedBondNftAtIndex(uint256 _index) public view returns (address) {
        require(_index < _whitelistedBondNfts.length(), "Index out of bounds");
        return _whitelistedBondNfts.at(_index);
    }
}
