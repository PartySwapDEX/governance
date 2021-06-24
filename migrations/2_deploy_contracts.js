const TreasuryVester = artifacts.require("TreasuryVester");
const LiquidityPoolManager = artifacts.require("LiquidityPoolManager");

module.exports = function (deployer) {
  // const YAY = '0xf1F94960f2EE20FCB123dd5B38a9ce277cAA9855'; //old without burnOwnTokens at fuji
  const YAY = '0x3d3D4D81D4D702e791480cD782C55B19A506b849'; // at fuji with burnOwnTokens.
  const WAVAX = '0xd00ae08403B9bbb9124bB305C09058E32C39A48c';

  deployer.deploy(TreasuryVester, YAY).then(
    () => {
      return deployer.deploy(LiquidityPoolManager, WAVAX, YAY, TreasuryVester.address);
    }
  );

};