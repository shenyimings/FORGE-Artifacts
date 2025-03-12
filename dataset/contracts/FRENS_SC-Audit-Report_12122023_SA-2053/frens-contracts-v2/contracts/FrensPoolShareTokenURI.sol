// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

///@title Frens Pool Share Token URI
///@author 0xWildhare and Frens team h/t scaffoldETH and budilGuidl
///@dev returns the image and metadata for the NFT bytes64 encoded

//import "hardhat/console.sol";
import "./interfaces/IStakingPool.sol";
import "./interfaces/IFrensPoolShare.sol";
import "./interfaces/IFrensMetaHelper.sol";
import "./interfaces/IFrensArt.sol";
import "./interfaces/IFrensPoolShareTokenURI.sol";
import "./interfaces/IFrensStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

contract FrensPoolShareTokenURI is IFrensPoolShareTokenURI {
    using Strings for uint256;

    IFrensPoolShare frensPoolShare;
    IFrensStorage frensStorage;

    constructor(
        IFrensStorage frensStorage_
    ) {
        frensStorage = frensStorage_;
        frensPoolShare = IFrensPoolShare(frensStorage.getAddress(keccak256(abi.encodePacked("contract.address", "FrensPoolShare"))));
    }

    function tokenURI(uint256 id) public view returns(string memory) {
        require(frensPoolShare.exists(id), "id does not exist");
        IFrensMetaHelper frensMetaHelper = IFrensMetaHelper(frensStorage.getAddress(keccak256(abi.encodePacked("contract.address", "FrensMetaHelper"))));
        IStakingPool stakingPool = IStakingPool(frensPoolShare.getPoolById(id));
        string memory poolState = stakingPool.getState();
        string memory depositString = frensMetaHelper.getDepositStringForId(id);
        uint shareForId = stakingPool.getDistributableShare(id);
        string memory shareString = frensMetaHelper.getEthDecimalString(
            shareForId
        );
        string memory stakingPoolAddress = Strings.toHexString(
            uint160(address(stakingPool)),
            20
        );
        string memory name = string(
            abi.encodePacked("fren pool share #", id.toString())
        );
        string memory description = string(
            abi.encodePacked(
                "this fren has a deposit of ",
                depositString,
                " Eth in pool ",
                stakingPoolAddress,
                ", with claimable balance of ",
                shareString,
                " Eth"
            )
        );

        string memory creator = Strings.toHexString(
            uint160(stakingPool.owner()),
            20
        );

        string memory image = Base64.encode(
            bytes(generateSVGofTokenById(id, stakingPool))
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name,
                                '", "description":"',
                                description,
                                '", "external_url":"https://app.frens.fun/pool/',
                                stakingPoolAddress,
                                '", "attributes": [{"trait_type": "pool", "value":"',
                                stakingPoolAddress,
                                //   '"},{"trait_type": "validator public key", "value": "',
                                //   pubKeyString,
                                '"},{"trait_type": "deposit", "value": "',
                                depositString,
                                " Eth",
                                '"},{"trait_type": "claimable", "value": "',
                                shareString,
                                " Eth",
                                '"},{"trait_type": "pool state", "value": "',
                                poolState,
                                '"},{"trait_type": "pool creator", "value": "',
                                creator,
                                '"}], "image": "',
                                "data:image/svg+xml;base64,",
                                image,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function generateSVGofTokenById(
        uint256 id,
        IStakingPool pool
    ) internal view returns (string memory) {
        IFrensArt frensArt = pool.artForPool();
        string memory svg = string(
            abi.encodePacked(
                '<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
                frensArt.renderTokenById(id),
                "</svg>"
            )
        );

        return svg;
    }
}
