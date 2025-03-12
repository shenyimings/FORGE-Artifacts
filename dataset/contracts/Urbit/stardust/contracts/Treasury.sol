// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "./interface/IAzimuth.sol";
import "./interface/IEcliptic.sol";
import "./StarToken.sol";

//  Treasury: simple automated market maker for StarTokens
//
//    This contract implements an extremely simple automated market maker for StarTokens.
//    It allows owners of Azimuth star points to deposit

contract Treasury is Context {
    // MODEL

    //  assets: stars currently held in this pool
    //
    uint16[] public assets;

    //  azimuth: points state data store
    //
    IAzimuth public azimuth;

    // deploy a new token contract with no balance and no operators
    StarToken public startoken = new StarToken(0, new address[](0));

    uint256 constant public oneStar = 1e18;

    // EVENTS

    event Deposit(
        uint32 indexed prefix,
        uint32 indexed star,
        address sender
    );

    event Redeem(
        uint32 indexed prefix,
        uint32 indexed star,
        address sender
    );

    // IMPLEMENTATION

    //  constructor(): configure the points data store and token contract address
    //
    constructor(IAzimuth _azimuth)
    {
        azimuth = _azimuth;
    }

    //  getAllAssets(): return array of assets held by this contract
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getAllAssets()
        view
        external
        returns (uint16[] memory allAssets)
    {
        return assets;
    }

    //  getAssetCount(): returns the number of assets held by this contract
    //
    function getAssetCount()
        view
        external
        returns (uint256 count)
    {
        return assets.length;
    }

    //  deposit(star): deposit a star you own, receive a newly-minted $STAR token in exchange
    //
    function deposit(uint16 _star)
        public
    {
        require(azimuth.getPointSize(_star) == IAzimuth.Size.Star);
        IEcliptic ecliptic = IEcliptic(azimuth.owner());

        // case (1):
        // star is owned by the caller, we are a transfer proxy for the star, and the star has spawned no planets
        if (
            azimuth.isOwner(_star, _msgSender()) &&
            azimuth.getSpawnCount(_star) == 0 &&
            azimuth.isTransferProxy(_star, address(this))
        ) {
            // transfer ownership of the _star to :this contract
            ecliptic.transferPoint(_star, address(this), true);
        }
        // case (2):
        // the star's galaxy is owned by the caller, the star is not active, and we are a spawn proxy for the galaxy
        else if (
            azimuth.isOwner(azimuth.getPrefix(_star), _msgSender()) &&
            !azimuth.isActive(_star) &&
            azimuth.isSpawnProxy(azimuth.getPrefix(_star), address(this))
        ) {
            // spawn the _star directly to :this contract
            ecliptic.spawn(_star, address(this));
        }
        else {
            revert();
        }

        //  update state to include the deposited star
        //
        assets.push(_star);

        //  mint star tokens and grant them to the :msg.sender
        //
        startoken.mint(_msgSender(), oneStar);
        emit Deposit(azimuth.getPrefix(_star), _star, _msgSender());
    }

    //  redeem(): burn one star token, receive ownership of the most recently deposited star in exchange
    //
    function redeem() public {
        // must have sufficient balance
        require(startoken.balanceOf(_msgSender()) >= oneStar);

        // there must be at least one star in the asset list
        require(assets.length>0);

        // remove the star to be redeemed
        uint16 _star = assets[assets.length-1];
        assets.pop();

        // check its ownership
        require(azimuth.isOwner(_star, address(this)));

        // burn the tokens
        startoken.ownerBurn(_msgSender(), oneStar);

        // transfer ownership
        IEcliptic ecliptic = IEcliptic(azimuth.owner());
        ecliptic.transferPoint(_star, _msgSender(), true);

        emit Redeem(azimuth.getPrefix(_star), _star, _msgSender());
    }
}
