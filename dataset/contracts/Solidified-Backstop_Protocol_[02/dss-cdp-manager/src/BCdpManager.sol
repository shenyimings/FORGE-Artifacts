pragma solidity ^0.5.12;

import { LibNote } from "dss/lib.sol";
import { DSAuth } from "ds-auth/auth.sol";
import { DssCdpManager } from "./DssCdpManager.sol";
import { LiquidationMachine, VatLike, EndLike, PriceFeedLike} from "./LiquidationMachine.sol";
import { BCdpScoreConnector, BCdpScoreLike } from "./BCdpScoreConnector.sol";

contract BCdpManager is BCdpScoreConnector, LiquidationMachine, DSAuth {
    constructor(address vat_, address end_, address pool_, address real_, address score_) public
        DssCdpManager(vat_)
        LiquidationMachine(VatLike(vat_), EndLike(end_), pool_, PriceFeedLike(real_))
        BCdpScoreConnector(BCdpScoreLike(score_))
    {

    }

    // Frob the cdp keeping the generated DAI or collateral freed in the cdp urn address.
    function frob(
        uint cdp,
        int dink,
        int dart
    ) public cdpAllowed(cdp) {
        bytes32 ilk = ilks[cdp];

        untop(cdp);
        updateScore(cdp, ilk, dink, dart, now);

        super.frob(cdp, dink, dart);
    }

    // Quit the system, migrating the cdp (ink, art) to a different dst urn
    function quit(
        uint cdp,
        address dst
    ) public cdpAllowed(cdp) urnAllowed(dst) {
        address urn = urns[cdp];
        bytes32 ilk = ilks[cdp];

        untop(cdp);
        (uint ink, uint art) = vat.urns(ilk, urn);
        updateScore(cdp, ilk, -toInt(ink), -toInt(art), now);

        super.quit(cdp, dst);
    }

    // Import a position from src urn to the urn owned by cdp
    function enter(
        address src,
        uint cdp
    ) public urnAllowed(src) cdpAllowed(cdp) {
        bytes32 ilk = ilks[cdp];

        untop(cdp);
        (uint ink, uint art) = vat.urns(ilk, src);
        updateScore(cdp, ilk, toInt(ink), toInt(art), now);

        super.enter(src, cdp);
    }

    // Move a position from cdpSrc urn to the cdpDst urn
    function shift(
        uint cdpSrc,
        uint cdpDst
    ) public cdpAllowed(cdpSrc) cdpAllowed(cdpDst) {
        bytes32 ilkSrc = ilks[cdpSrc];

        untop(cdpSrc);
        untop(cdpDst);

        address src = urns[cdpSrc];

        (uint inkSrc, uint artSrc) = vat.urns(ilkSrc, src);

        updateScore(cdpSrc, ilkSrc, -toInt(inkSrc), -toInt(artSrc), now);
        updateScore(cdpDst, ilkSrc, toInt(inkSrc), toInt(artSrc), now);

        super.shift(cdpSrc, cdpDst);
    }

    ///////////////// B specific control functions /////////////////////////////

    function quitB(uint cdp) external cdpAllowed(cdp) note {
        quitScore(cdp);
        quitBLiquidation(cdp);
    }

    function setScoreContract(BCdpScoreLike _score) external auth {
        super.setScore(_score);
    }

    function setPoolContract(address _pool) external auth {
        super.setPool(_pool);
    }
}
