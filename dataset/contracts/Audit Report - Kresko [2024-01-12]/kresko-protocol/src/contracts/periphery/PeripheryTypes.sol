// solhint-disable state-visibility, max-states-count, var-name-mixedcase, no-global-import, const-name-snakecase, no-empty-blocks, no-console
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Asset, RawPrice} from "common/Types.sol";

library Fe {
    function getProtocol(FAsset[] memory assets) internal view returns (FType.Protocol memory);

    function getAssets() internal view returns (FType.FAsset[] memory);

    function getAsset(address addr) internal view returns (FType.FAsset memory);

    function getMinter() internal view returns (FType.Minter memory);

    function getSCDP() internal view returns (FType.SCDP memory);

    function getSDebts(address addr) internal view returns (FType.SDebt[] memory);

    function getGate() internal view returns (FType.Gate memory);

    function getMUser(address addr) internal view returns (FType.MUser memory);

    function getBalance(address addr, address token) internal view returns (FType.Balance memory);

    function getMDeposits(address addr) internal view returns (FType.MDeposit[] memory);

    function getMDebts(address addr) internal view returns (FType.MDebt[] memory);

    function getSUser(address addr) internal view returns (FType.SUser memory);

    function getSDeposits(address addr) internal view returns (FType.SDeposit[] memory);
}

library FType {
    struct Protocol {
        FAsset[] assets;
        Minter minter;
        SCDP scdp;
        uint32 staleTime;
        uint32 seqGracePreiod;
        uint16 priceDeviation;
        uint8 pricePrecision;
        uint8 gate;
        bool sequencerUp;
        Gate gate;
    }

    struct User {
        address addr;
        Balance[] bals;
        MUser minter;
        SUser scdp;
    }

    struct Balance {
        address addr;
        address token;
        string symbol;
        uint256 amount;
        uint256 val;
        uint8 decimals;
    }

    struct Minter {
        uint32 MCR;
        uint32 LT;
        uint32 MLM;
        uint64 minDebt;
    }

    struct SCDP {
        uint32 MCR;
        uint32 LT;
        uint32 MLM;
        uint16 CR;
        uint256 collVal;
        uint256 debtVal;
        uint256 coverVal;
        SDeposit[] deposits;
        SDebt[] debts;
    }

    struct Gate {
        address kreskian;
        address questForKresk;
        uint8 phase;
        uint8[] restrictions;
    }

    struct FAsset {
        address addr;
        string name;
        string symbol;
        uint256 tSupply;
        uint256 price;
        bool open;
        RawPrice priceRaw;
        Asset asset;
    }

    struct MUser {
        uint256 collVal;
        uint256 debtVal;
        uint16 cr;
        MDeposit[] deposits;
        MDebt[] mints;
    }

    struct MDebt {
        uint256 amount;
        uint256 val;
        Asset asset;
    }

    struct MDeposit {
        uint256 amount;
        uint256 val;
        Asset asset;
    }

    struct SUser {
        uint256 collVal;
        uint256 profitVal;
        SDeposit[] deposits;
    }

    struct SDeposit {
        uint256 amount;
        uint256 val;
        uint256 fees;
        uint256 valFees;
        Asset asset;
    }
    struct SDebt {
        uint256 amount;
        uint256 val;
        Asset asset;
    }
}
