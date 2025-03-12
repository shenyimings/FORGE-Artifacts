// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {AccessControlMixin, AccessControl} from "../polygon/AccessControlMixin.sol";
import {IMintableERC721} from "../polygon/IMintableERC721.sol";
import {NativeMetaTransaction} from "../polygon/NativeMetaTransaction.sol";

/**
 * @notice this is a receiver contract on Mainnet that should take the token when the user wish to exit from the Polygon network onto Mainnet
 */
contract OriginPolygonReceiverERC721_v1 is
    ERC721Enumerable,
    AccessControlMixin,
    NativeMetaTransaction,
    IMintableERC721
{
    bytes32 public constant PREDICATE_ROLE = keccak256("PREDICATE_ROLE");

    string private _base;

    event WithdrawnBatch(address indexed user, uint256[] tokenIds);
    event TransferWithMetadata(address indexed from, address indexed to, uint256 indexed tokenId, bytes metaData);

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) ERC721(name_, symbol_) {
        _base = baseURI_;
        _setupContractId("ChildMintableERC721");
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PREDICATE_ROLE, _msgSender());
        _initializeEIP712(name_);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC721Enumerable, IERC165) returns (bool) {
      return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _base;
    }

    /**
     * @notice Return URI to contract metadata JSON file
     * @return URI to JSON file
     */
    function contractURI() public view returns (string memory) {
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, "contract.json")) : "";
    }

    /**
     * @notice Change the base url for all NFTs
     */
    function setBaseURI(string calldata base) external only(DEFAULT_ADMIN_ROLE) {
        _base = base;
    }

    /**
     * @dev See {IMintableERC721-mint}.
     */
    function mint(address user, uint256 tokenId) external override only(PREDICATE_ROLE) {
        _mint(user, tokenId);
    }

    /**
     * If you're attempting to bring metadata associated with token
     * from L2 to L1, you must implement this method, to be invoked
     * when minting token back on L1, during exit
     */
    function setTokenMetadata(uint256 tokenId, bytes memory data) internal virtual {
        // This function should decode metadata obtained from L2
        // and attempt to set it for this `tokenId`
        //
        // Following is just a default implementation, feel
        // free to define your own encoding/ decoding scheme
        // for L2 -> L1 token metadata transfer
        //
        // NOTE: we are only using base URI here, so then the custom uri per tokenId is ignored
        //
        // string memory uri = abi.decode(data, (string));


        //_setTokenURI(tokenId, uri);
    }

    /**
     * @dev See {IMintableERC721-mint}.
     *
     * If you're attempting to bring metadata associated with token
     * from L2 to L1, you must implement this method
     */
    function mint(address user, uint256 tokenId, bytes calldata metaData) external override only(PREDICATE_ROLE) {
        _mint(user, tokenId);

        setTokenMetadata(tokenId, metaData);
    }


    /**
     * @dev See {IMintableERC721-exists}.
     */
    function exists(uint256 tokenId) external view override returns (bool) {
        return _exists(tokenId);
    }
}
