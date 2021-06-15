const TreasuryVester = artifacts.require("TreasuryVester");
const LiquidityPoolManager = artifacts.require("LiquidityPoolManager");


module.exports = function (deployer) {
  const YAY = '0xf1F94960f2EE20FCB123dd5B38a9ce277cAA9855';
  const WAVAX = '0xd00ae08403B9bbb9124bB305C09058E32C39A48c';

  deployer.deploy(TreasuryVester, YAY).then(
    () => {
      return deployer.deploy(LiquidityPoolManager, WAVAX, YAY, TreasuryVester.address);
    }
  );

};