// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.6;

import "./../utils/ERC721Enhanced.sol";


/**
 * @title Mock ERC721
 * @author solace.fi
 * @notice Mock ERC721 is only used to test other contracts.
 */
contract MockERC721 is ERC721Enhanced {

    // Count of all tokens created.
    uint256 internal _tokenCount = 0;

    struct AfterTransfer {
        address from;
        address to;
        uint256 tokenID;
    }

    AfterTransfer public lastTransfer;

    /**
     * @notice Constructs the Mock Token contract.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     */
    constructor(
        string memory name,
        string memory symbol
    )
    // solhint-disable-next-line no-empty-blocks
    ERC721Enhanced(name, symbol) { }

    /**
     * @notice Mints a new token.
     * @param recipient The recipient of the token.
     * @return tokenID The ID of the new token.
     */
    function mint(address recipient) external returns (uint256 tokenID) {
        tokenID = ++_tokenCount; // autoincrement from 1
        _mint(recipient, tokenID);
        return tokenID;
    }

    /**
     * @notice Burns a token.
     * @param tokenID The token to burn.
     */
    function burn(uint256 tokenID) external {
        _burn(tokenID);
    }

    /**
     * @notice Count of all tokens created.
     * @return count Count.
     */
    function tokenCount() external view returns (uint256 count) {
        return _tokenCount;
    }

    /**
     * @notice Do a thing to a token.
     * @param tokenID The ID of the token to do stuff to.
     * @return res The result.
     */
    function doThing1(uint256 tokenID) external tokenMustExist(tokenID) returns (uint256 res) {
        return tokenID * 2;
    }

    /**
     * @notice Do a thing to a token.
     * @param tokenID The ID of the token to do stuff to.
     * @return res The result.
     */
    function doThing2(uint256 tokenID) external onlyOwner(tokenID) returns (uint256 res) {
        return tokenID * 3;
    }

    /**
     * @notice Do a thing to a token.
     * @param tokenID The ID of the token to do stuff to.
     * @return res The result.
     */
    function doThing3(uint256 tokenID) external onlyOwnerOrApproved(tokenID) returns (uint256 res) {
        return tokenID * 4;
    }

    /**
     * @notice Get the base URI.
     */
    function getBaseURI() external view returns (string memory) {
        return _baseURI();
    }

    /**
     * @notice Sets the base URI for computing `tokenURI`.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param baseURI_ The new base URI.
     */
    function setBaseURI(string memory baseURI_) external {
        _setBaseURI(baseURI_);
    }

    /**
     * @notice Hook that is called after any token transfer. This includes minting and burning.
     * @param from The user that sends the token, or zero if minting.
     * @param to The zero that receives the token, or zero if burning.
     * @param tokenID The ID of the token being transferred.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenID
    ) internal virtual override {
        super._afterTokenTransfer(from, to, tokenID);
        lastTransfer = AfterTransfer({
            from: from,
            to: to,
            tokenID: tokenID
        });
    }
}
