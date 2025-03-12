// SPDX-License-Identifier: Ulicense
pragma solidity ^0.8.6;

contract Erc721Mock {
    mapping(uint256 => address) public ownerOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(uint256 => address) public getApproved;
    uint256 public totalSupply;
    struct Royalty {
        address minter;
        uint256 fee;
    }

    mapping(uint256 => Royalty) _royalty;

    function mint(
        uint256 num,
        address own,
        uint256 royalty
    ) external {
        uint256 i;
        for (i; i < num; i++) {
            totalSupply++;
            ownerOf[totalSupply] = own;
            _royalty[totalSupply] = Royalty(own, royalty);
        }
    }

    function setOperator(address op) external {
        isApprovedForAll[msg.sender][op] = true;
    }

    function approve(address user, uint256 token) external {
        require(ownerOf[token] == msg.sender, "approve: not an owner");
        getApproved[token] = user;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {
        if (ownerOf[tokenId] != from) {
            if (getApproved[tokenId] != msg.sender) {
                require(
                    isApprovedForAll[from][msg.sender],
                    "TransferFrom: no approval"
                );
            }
        } else {
            require(from == msg.sender, "TransferFrom: Not an owner");
        }
        delete getApproved[tokenId];
        ownerOf[tokenId] = to;
    }

    function royaltyInfo(uint256 token)
        external
        view
        returns (address receiver, uint256 amount)
    {
        Royalty storage r = _royalty[token];
        return (r.minter, r.fee);
    }

    event RoyaltyReceived(
        address firstOwner,
        address buyer,
        uint256 tokenId,
        address tokenPaid,
        uint256 amount
    );

    function receivedRoyalties(
        address _firstOwner,
        address _buyer,
        uint256 _tokenId,
        address _tokenPaid,
        uint256 _amount
    ) external {
        emit RoyaltyReceived(
            _firstOwner,
            _buyer,
            _tokenId,
            _tokenPaid,
            _amount
        );
    }
}
