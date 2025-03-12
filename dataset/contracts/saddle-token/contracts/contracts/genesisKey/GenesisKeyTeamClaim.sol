// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IGK {
    function ownerOf(uint256 tokenId) external view returns (address);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

contract GenesisKeyTeamClaim is Initializable, UUPSUpgradeable {
    using SafeMathUpgradeable for uint256;

    address public owner;
    address public genesisKeyMerkle;
    IGK public GK;
    uint256[] public ownedTokenIds;
    event ClaimedGenesisKey(address indexed _user, uint256 _amount, uint256 _blockNum, bool _whitelist);
    event TeamGK(uint256 tokenId);

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    function initialize(IGK _GK) public initializer {
        __UUPSUpgradeable_init();

        GK = _GK;
        owner = msg.sender;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    // governance functions =================================================================
    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function setGenesisKeyMerkle(address _newMK) external onlyOwner {
        genesisKeyMerkle = _newMK;
    }

    function addOwedTokenIds(uint256[] calldata tokenIds) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(GK.ownerOf(tokenIds[i]) == address(this));
            ownedTokenIds.push(tokenIds[i]);
            emit TeamGK(tokenIds[i]);
        }
    }

    function removeOwedTokenIds(uint256 duplicateTokenId) external onlyOwner {
        bool seen = false;
        for (uint256 i = 0; i < ownedTokenIds.length; i++) {
            if (ownedTokenIds[i] == duplicateTokenId) {
                if (seen) {
                    ownedTokenIds[i] = ownedTokenIds[ownedTokenIds.length - 1];
                    ownedTokenIds.pop();
                    break;
                } else {
                    seen = true;
                }
            }
        }
    }

    function addTokenId(uint256 newTokenId) external {
        require(msg.sender == address(GK));
        require(GK.ownerOf(newTokenId) == address(this));
        ownedTokenIds.push(newTokenId);
        emit TeamGK(newTokenId);
    }

    // =========POST WHITELIST CLAIM KEY ==========================================================================
    /**
     @notice allows winning keys to be self-minted by winners
    */
    function teamClaim(address recipient) external returns (bool) {
        // checks
        require(msg.sender == genesisKeyMerkle);

        // effects
        // interactions
        if (ownedTokenIds.length != 0) {
            GK.transferFrom(address(this), recipient, ownedTokenIds[0]);

            if (ownedTokenIds.length > 1) {
                ownedTokenIds[0] = ownedTokenIds[ownedTokenIds.length - 1];
            }

            ownedTokenIds.pop();

            emit ClaimedGenesisKey(recipient, 0, block.number, true);
            return true;
        }

        return false;
    }
}
