// 
// Inverse P3DCI ODT
// v0.2.1
//

import "utilities";
import "utilities-aces";

/* ----- ODT Parameters ------ */
const Chromaticities DISPLAY_PRI = P3DCI_PRI;
const float OCES_PRI_2_XYZ_MAT[4][4] = RGBtoXYZ(ACES_PRI,1.0);
const float DISPLAY_PRI_2_XYZ_MAT[4][4] = RGBtoXYZ(DISPLAY_PRI,1.0);

const Chromaticities RENDERING_PRI = 
{
  {0.73470, 0.26530},
  {0.00000, 1.00000},
  {0.12676, 0.03521},
  {0.32168, 0.33767}
};
const float XYZ_2_RENDERING_PRI_MAT[4][4] = XYZtoRGB(RENDERING_PRI,1.0);
const float RENDERING_PRI_2_XYZ_MAT[4][4] = RGBtoXYZ(RENDERING_PRI,1.0);
const float XYZ_2_OCES_PRI_MAT[4][4] = XYZtoRGB(ACES_PRI,1.0);
const float RENDERING_PRI_2_OCES_MAT[4][4] = mult_f44_f44( RENDERING_PRI_2_XYZ_MAT, XYZ_2_OCES_PRI_MAT);

// ODT parameters related to black point compensation (BPC) and encoding
const float ODT_OCES_BP = 0.0001;
const float ODT_OCES_WP = 48.0;
const float OUT_BP = 0.0048;
const float OUT_WP = 48.0;

const float DISPGAMMA = 2.6; 
const unsigned int BITDEPTH = 12;
const unsigned int CV_BLACK = 0;
const unsigned int CV_WHITE = pow( 2, BITDEPTH) - 1;
const unsigned int MIN_CV = 0;
const unsigned int MAX_CV = pow( 2, BITDEPTH) - 1;

// Derived BPC and scale parameters
const float BPC = (ODT_OCES_BP * OUT_WP - ODT_OCES_WP * OUT_BP) / 
                  (ODT_OCES_BP - ODT_OCES_WP);
const float SCALE = (OUT_BP - OUT_WP) / (ODT_OCES_BP - ODT_OCES_WP);




void main 
(
  input varying float rIn, 
  input varying float gIn, 
  input varying float bIn, 
  input varying float aIn,
  output varying float rOut,
  output varying float gOut,
  output varying float bOut,
  output varying float aOut
)
{
  // Put input variables (display code values) into a 3-element vector
  float outputCV[3] = {rIn, gIn, bIn};

  // This step converts 0-1 normalized code values back to integral code values
  outputCV[0] = outputCV[0] * MAX_CV;
  outputCV[1] = outputCV[1] * MAX_CV;
  outputCV[2] = outputCV[2] * MAX_CV;

  // Inverse CCTF
  float linearCV[3]; // in display primary RGB encoding
  linearCV[0] = pow( outputCV[0] / CV_WHITE, DISPGAMMA);
  linearCV[1] = pow( outputCV[1] / CV_WHITE, DISPGAMMA);
  linearCV[2] = pow( outputCV[2] / CV_WHITE, DISPGAMMA);
    
  // Convert display primaries to CIE XYZ
  float XYZ[3] = mult_f3_f44( linearCV, DISPLAY_PRI_2_XYZ_MAT);
  
  // Convert CIE XYZ to rendering RGB
  linearCV = mult_f3_f44( XYZ, XYZ_2_RENDERING_PRI_MAT); // in rendering primary RGB encoding
  
  // Code value to luminance conversion. Scales CV 1.0 to the white point 
  // luminance, OUT_WP and CV 0.0 to OUT_BP.
  float offset_scaled[3];
  offset_scaled[0] = linearCV[0] * (OUT_WP - OUT_BP) + OUT_BP;
  offset_scaled[1] = linearCV[1] * (OUT_WP - OUT_BP) + OUT_BP;
  offset_scaled[2] = linearCV[2] * (OUT_WP - OUT_BP) + OUT_BP;

  // Undo black point compensation
  float rgbPre[3];
  rgbPre[0] = (offset_scaled[0] - BPC) / SCALE;
  rgbPre[1] = (offset_scaled[1] - BPC) / SCALE;
  rgbPre[2] = (offset_scaled[2] - BPC) / SCALE;

    // Apply inverse tonescale independently to RGB
    float rgbPost[3];  
    rgbPost[0] = odt_tonescale_rev( clamp(rgbPre[0],0.0,HALF_POS_INF));
    rgbPost[1] = odt_tonescale_rev( clamp(rgbPre[1],0.0,HALF_POS_INF));
    rgbPost[2] = odt_tonescale_rev( clamp(rgbPre[2],0.0,HALF_POS_INF));    

  float rgbRestored[3] = restore_hue_dw3( rgbPre, rgbPost);

  // Rendering primaries to OCES
  float oces[3] = mult_f3_f44( rgbRestored, RENDERING_PRI_2_OCES_MAT);

  rOut = oces[0];
  gOut = oces[1];
  bOut = oces[2];
  aOut = aIn;
}