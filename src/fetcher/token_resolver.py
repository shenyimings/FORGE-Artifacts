import json
import time
import httpx
from pathlib import Path
from loguru import logger

COINGECKO_COINS_LIST_URL = "https://api.coingecko.com/api/v3/coins/list"

KNOWN_TOKEN_IDS = {
    "usdt":  "tether",
    "usdc":  "usd-coin",
    "dai":   "multi-collateral-dai",
    "weth":  "weth",
    "wbtc":  "wrapped-bitcoin",
    "bnb":   "binancecoin",
    "matic": "matic-network",
    "link":  "chainlink",
    "uni":   "uniswap",
    "aave":  "aave",
    "crv":   "curve-dao-token",
    "comp":  "compound-governance-token",
    "mkr":   "maker",
    "snx":   "havven",
    "frax":  "frax",
}

CHAIN_TO_PLATFORM = {
    "eth": "ethereum",
    "ethereum": "ethereum",
    "bsc": "binance-smart-chain",
    "binance": "binance-smart-chain",
    "polygon": "polygon-pos",
    "matic": "polygon-pos",
    "base": "base",
    "arbitrum": "arbitrum-one",
    "arb": "arbitrum-one",
    "optimism": "optimistic-ethereum",
    "op": "optimistic-ethereum",
    "avalanche": "avalanche",
    "avax": "avalanche",
    "fantom": "fantom",
    "ftm": "fantom",
}


class TokenResolver:
    def __init__(self, cache_path: str = "logs/coingecko_cache.json"):
        self.cache_path = Path(cache_path)
        self._coins: list = []

    def resolve(self, token_name: str, chain: str) -> str:
        """
        Resolve a token name/symbol + chain to a contract address.

        Args:
            token_name: Token symbol or name (e.g., "USDT", "DAI")
            chain: Chain name as extracted (e.g., "eth", "bsc")

        Returns:
            Contract address string or "n/a" if not found
        """
        if not token_name or token_name == "n/a":
            return "n/a"
        if not chain or chain == "n/a":
            return "n/a"

        platform = CHAIN_TO_PLATFORM.get(chain.lower())
        if not platform:
            logger.warning("Unknown chain '{}', cannot resolve token address", chain)
            return "n/a"

        coins = self._load_coins()
        if not coins:
            logger.warning("CoinGecko coins list is empty, skipping token resolution")
            return "n/a"

        symbol_lower = token_name.lower()
        preferred_id = KNOWN_TOKEN_IDS.get(symbol_lower)

        # Collect all symbol matches
        candidates = [
            coin for coin in coins
            if coin.get("symbol", "").lower() == symbol_lower
        ]

        # Sort by platform count descending (more platforms = more established)
        candidates.sort(key=lambda c: len(c.get("platforms", {})), reverse=True)

        # Check preferred ID first if we have one
        if preferred_id:
            for coin in candidates:
                if coin.get("id") == preferred_id:
                    address = coin.get("platforms", {}).get(platform)
                    if address:
                        logger.info(
                            "Resolved {} on {} → {} (known token id={})",
                            token_name, chain, address, preferred_id,
                        )
                        return address

        # Fall back to highest platform-count candidate that has an address on this chain
        for coin in candidates:
            address = coin.get("platforms", {}).get(platform)
            if address:
                logger.info(
                    "Resolved {} on {} → {} (coin id={})",
                    token_name, chain, address, coin.get("id"),
                )
                return address

        logger.warning(
            "Could not resolve address for {} on {}", token_name, chain
        )
        return "n/a"

    def _load_coins(self) -> list:
        if self._coins:
            return self._coins
        if self.cache_path.exists():
            logger.debug("Loading CoinGecko cache from {}", self.cache_path)
            try:
                with self.cache_path.open("r", encoding="utf-8") as f:
                    self._coins = json.load(f)
                return self._coins
            except (json.JSONDecodeError, OSError) as e:
                logger.warning(
                    "Failed to load CoinGecko cache from {}: {}. Refetching...",
                    self.cache_path,
                    e,
                )
                try:
                    # Remove corrupted cache so it can be rebuilt cleanly
                    self.cache_path.unlink(missing_ok=True)
                except OSError as unlink_err:
                    logger.warning(
                        "Failed to delete corrupted CoinGecko cache {}: {}",
                        self.cache_path,
                        unlink_err,
                    )
        return self._fetch_and_cache()

    def _fetch_and_cache(self) -> list:
        logger.info("Fetching CoinGecko coins list (this may take a moment)...")
        for attempt in range(3):
            try:
                with httpx.Client(timeout=30.0) as client:
                    resp = client.get(
                        COINGECKO_COINS_LIST_URL,
                        params={"include_platform": "true"},
                    )
                    resp.raise_for_status()
                    self._coins = resp.json()
                    self.cache_path.parent.mkdir(parents=True, exist_ok=True)
                    with self.cache_path.open("w", encoding="utf-8") as f:
                        json.dump(self._coins, f)
                    logger.info(
                        "Cached {} coins to {}", len(self._coins), self.cache_path
                    )
                    return self._coins
            except Exception as e:
                logger.warning(
                    "CoinGecko fetch attempt {}/3 failed: {}", attempt + 1, e
                )
                if attempt + 1 < 3:
                    time.sleep(3)
        logger.error("All CoinGecko fetch attempts failed")
        return []
