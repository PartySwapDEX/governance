const TreasuryVester = artifacts.require("TreasuryVester");
const LiquidityPoolManager = artifacts.require("LiquidityPoolManager");

module.exports = function (deployer) {
  const YAY = '0x0f2D40e9dcaEe7792665a420feB52E76709dC53A'; // at fuji latest.
  // const YAY = '0x10b3A2445f29F838ed8D9d61a82205A0436B7F75'; // at mainnet with burnOwnTokens. isn't pupu
  // const WAVAX = '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7'; // at mainnet.
  const WAVAX = '0xd00ae08403B9bbb9124bB305C09058E32C39A48c'; // at fuji
  deployer.deploy(TreasuryVester, YAY).then(
    () => {
      return deployer.deploy(LiquidityPoolManager, WAVAX, YAY, TreasuryVester.address);
    }
  );

};