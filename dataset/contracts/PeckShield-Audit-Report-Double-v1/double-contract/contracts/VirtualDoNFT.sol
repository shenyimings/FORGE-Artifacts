// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./BaseDoNFT.sol";

contract VirtualDoNFT is BaseDoNFT{

    function mintXNft(uint256 oid) public nonReentrant override virtual returns(uint256 tid) {
        require(oid2xid[oid] == 0, "already warped");
        require(onlyApprovedOrOwner(tx.origin,oNftAddress,oid) || onlyApprovedOrOwner(msg.sender,oNftAddress,oid),"only approved or owner");
        tid = mintDoNft(address(this),oid,uint64(block.timestamp),type(uint64).max);
        oid2xid[oid] = tid;
    }

    function mintVNft(uint256 oid) public virtual returns(uint256 tid) {
        tid = mintXNft(oid);
    }

    function isVNft(uint256 tokenId)public view returns (bool){
        return isXNft(tokenId);
    }
    
    function getVNftId(uint256 originalNftId) public view returns(uint256){
        return getXNftId(originalNftId);
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        if(isXNft(tokenId)){
            DoNftInfo storage info = doNftMapping[tokenId];
            return ERC721(oNftAddress).ownerOf(info.oid);
        }
        return super.ownerOf(tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal override view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override virtual {
        require(!isXNft(tokenId),"cannot transfer wNft");
        ERC721._transfer(from, to, tokenId);
    }


}
