// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ILongVoucher.sol";
import "./ILongVoucherMetadataProvider.sol";
import "./IVoucherSVG.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@solvprotocol/erc-3525/periphery/interface/IERC3525MetadataDescriptor.sol";

contract LongVoucherMetadataDescriptor is
    Ownable2StepUpgradeable,
    IERC3525MetadataDescriptor
{
    using StringsUpgradeable for address;
    using StringsUpgradeable for uint256;

    // the LongVoucher contract
    ILongVoucher public longVoucher;

    // description of LongVoucher contract
    string public contractDesc;

    // slot manager => ILongVoucherMetadataProvider
    mapping(address => address) private _metadataProviders;

    /// events

    event MetaDataProviderChanged(address oldMetadataProvider, address newMetadataProvider);

    function initialize(
        address longVoucher_,
        address initialOwner_
    ) public initializer {
        require(longVoucher_ != address(0), "Zero LongVoucher address");
        require(initialOwner_ != address(0), "Zero initial owner address");

        // call super 
        Ownable2StepUpgradeable.__Ownable2Step_init();

        // initialize longVoucher
        longVoucher = ILongVoucher(longVoucher_);

        // initialize owner
        _transferOwnership(initialOwner_);
    }

    /// view
    function getMetadataProvider(address slotManager) external view returns (address) {
        return _metadataProviders[slotManager];
    }

    /// admin functions

    function setContractDesc(string memory contractDesc_) external onlyOwner {
        contractDesc = contractDesc_;
    }

    function setMetadataProvider(address slotManager, address metadataProvider) external onlyOwner {
        // require(longVoucher.isSlotManager(slotManager), "Not slot manager");
        require(metadataProvider != address(0), "Zero address");

        address oldMetadataProvider = _metadataProviders[slotManager];
        _metadataProviders[slotManager] = metadataProvider;

        emit MetaDataProviderChanged(oldMetadataProvider, metadataProvider);
    } 

    /// implement IERC3525MetadataDescriptor  

    function constructContractURI()
        external
        view
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    'data:application/json;{"name":"',
                    longVoucher.name(),
                    '","symbol":"',
                    longVoucher.symbol(),
                    '","description":"',
                    contractDesc,
                    '","valueDecimals":"',
                    uint256(longVoucher.valueDecimals()).toString(),
                    '","attributes":{}}'
                )
            );
    }

    function constructSlotURI(
        uint256 slot
    ) external view override returns (string memory) {
        address slotManager = longVoucher.managerOf(slot);

        ILongVoucherMetadataProvider metadataProvider = ILongVoucherMetadataProvider(_metadataProviders[slotManager]);
        ILongVoucherMetadataProvider.LongVoucherMetadata memory slotMetadata = metadataProvider.slotMetadata(slot);
        bytes memory attributes = _buildAttributes(slotMetadata);
        return
            string(
                abi.encodePacked(
                    'data:application/json;{"name":"',
                    slotMetadata.name,
                    '","description":"',
                    slotMetadata.desc,
                    '","external_url":"',
                    slotMetadata.link,
                    '","attributes":',
                    attributes,
                    '}'
                )
            );
    }

    function constructTokenURI(
        uint256 tokenId
    ) external view override returns (string memory) {
        address slotManager = longVoucher.managerOf(longVoucher.slotOf(tokenId));

        ILongVoucherMetadataProvider metadataProvider = ILongVoucherMetadataProvider(_metadataProviders[slotManager]);
        ILongVoucherMetadataProvider.LongVoucherMetadata memory tokenMetadata = metadataProvider.tokenMetadata(tokenId);
        address voucherSVG = metadataProvider.voucherSVG(tokenId);
        bytes memory attributes = _buildAttributes(tokenMetadata);
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64Upgradeable.encode(
                        abi.encodePacked(
                            '{"name":"',
                            tokenMetadata.name,
                            '","description":"',
                            tokenMetadata.desc,
                            '","image":"data:image/svg+xml;base64,',
                            Base64Upgradeable.encode(IVoucherSVG(voucherSVG).generateSVG(tokenId)),
                            '","external_url":"',
                            tokenMetadata.link,
                            '","attributes":',
                            attributes,
                            "}"
                        )
                    )
                )
            );
    }

    /// internal functions

    function _buildAttributes(
        ILongVoucherMetadataProvider.LongVoucherMetadata memory metadata
    ) private pure returns (bytes memory data) {
        ILongVoucherMetadataProvider.Attribute memory attribute0 = metadata.attributes[0];
        if (bytes(attribute0.name).length == 0) {
            return abi.encodePacked("{}");
        }

        data = abi.encodePacked("[", _buildTrait(attribute0.name, attribute0.value, attribute0.desc, "string"));
        for (uint256 i = 1; i < metadata.attributes.length; i++) {
            ILongVoucherMetadataProvider.Attribute memory attribute = metadata.attributes[i];
            if (bytes(attribute.name).length == 0) {
                break;
            }

            data = abi.encodePacked(data, ",", _buildTrait(attribute.name, attribute.value, attribute.desc, "string"));
        }
        data = abi.encodePacked(data, "]");
    }

    function _buildTrait(
        string memory traitName,
        string memory traitValue,
        string memory description,
        string memory displayType
    ) private pure returns (bytes memory data) {
        data = abi.encodePacked(
            "{",
            '"trait_type":"',
            traitName,
            '","value":"',
            traitValue,
            '","description":"',
            description,
            '","display_type":"',
            displayType,
            '"',
            "}"
        );
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
