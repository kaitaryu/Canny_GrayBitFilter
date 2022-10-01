Shader "Custom/Canny_GrayBitFilter"
{
	Properties{
		[Enum(UnityEngine.Rendering.CullMode)]
		_Cull("Cull", Float) = 0
		_Weaken_White("Weaken_White", Float) = 0.8
	}

		SubShader{
			Tags {
				"Queue" = "Transparent"
				"RenderType" = "Transparent"
			}
			ZWrite Off
			Cull[_Cull]

			//GrabPassでレンダリング結果を取得
			GrabPass {}

			Pass {

				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile _MODE_MOSAIC1_NORMAL _MODE_MOSAIC2_AVERAGE _MODE_BLUR1_NORMAL _MODE_BLUR2_GAUSS
				#include "UnityCG.cginc"

				struct appdata {
					float4 vertex : POSITION;
				};

				struct v2f {
					float4 vertex : SV_POSITION;
					float4 grabPos : TEXCOORD0;
				};

				sampler2D _GrabTexture;
				float4 _GrabTexture_ST;
				float4	_GrabTexture_TexelSize;
				float _Weaken_White;

				v2f vert(appdata v) {
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);
					o.grabPos = ComputeGrabScreenPos(o.vertex);
					return o;
				}
				fixed4 Sobel_x(float2 uv,int point_x,int point_y )
				{
					fixed4 sobel;
					sobel = tex2D(_GrabTexture, uv + float2((1 + point_x) * _GrabTexture_TexelSize.x , (-1 + point_y) * _GrabTexture_TexelSize.y));
					sobel += 2 * tex2D(_GrabTexture, uv + float2((1 + point_x) * _GrabTexture_TexelSize.x, ( point_y) * _GrabTexture_TexelSize.y));
					sobel += tex2D(_GrabTexture, uv + float2((1 + point_x) * _GrabTexture_TexelSize.x, (1 + point_y)* _GrabTexture_TexelSize.y));

					sobel -= tex2D(_GrabTexture, uv + float2((-1 + point_x) * _GrabTexture_TexelSize.x, (-1 + point_y)* _GrabTexture_TexelSize.y));
					sobel -= 2*tex2D(_GrabTexture, uv + float2((-1 + point_x) * _GrabTexture_TexelSize.x, (point_y)* _GrabTexture_TexelSize.y));
					sobel -= tex2D(_GrabTexture, uv + float2((-1 + point_x) * _GrabTexture_TexelSize.x, (1 + point_y)* _GrabTexture_TexelSize.y));

					return sobel;
				}
				fixed4 Sobel_y(float2 uv, int point_x, int point_y)
				{
					fixed4 sobel;
					sobel = tex2D(_GrabTexture, uv + float2((-1 + point_x) * _GrabTexture_TexelSize.x, (1 + point_y) * _GrabTexture_TexelSize.y));
					sobel += 2 * tex2D(_GrabTexture, uv + float2(point_x * _GrabTexture_TexelSize.x, (1 + point_y) * _GrabTexture_TexelSize.y));
					sobel += tex2D(_GrabTexture, uv + float2((1 + point_x) * _GrabTexture_TexelSize.x, (1 + point_y) * _GrabTexture_TexelSize.y));

					sobel -= tex2D(_GrabTexture, uv + float2((-1 + point_x) * _GrabTexture_TexelSize.x, (-1 + point_y) * _GrabTexture_TexelSize.y));
					sobel -= 2 * tex2D(_GrabTexture, uv + float2((point_x) * _GrabTexture_TexelSize.x, (-1 + point_y) * _GrabTexture_TexelSize.y));
					sobel -= tex2D(_GrabTexture, uv + float2((1 + point_x) * _GrabTexture_TexelSize.x, (-1 + point_y) * _GrabTexture_TexelSize.y));

					return sobel;
				}
				fixed4 Get_Gradation(float2 uv, int point_x, int point_y)
				{
					fixed4 sobel_x, sobel_y;
					fixed4 gradation;
					sobel_x = Sobel_x(uv, point_x, point_y);
					sobel_y = Sobel_y(uv, point_x, point_y);
					gradation = sqrt(sobel_y * sobel_y + sobel_x * sobel_x);
					return gradation;
				}
				fixed4 Canny_filter(float2 uv)
				{
					fixed4 sobel_x, sobel_y;
					fixed4 gradation;
					fixed4 angle;
					fixed4 sin_num,cos_num;
					float r,g,b,gr;
					sobel_x = Sobel_x(uv,0,0);
					sobel_y = Sobel_y(uv, 0, 0);

					gradation = sqrt(sobel_y * sobel_y + sobel_x * sobel_x);
					angle = atan(sobel_y / sobel_x);
					//法線方向を求める
					cos_num = round(trunc(sin(angle) / 0.38) / (abs(trunc(sin(angle) / 0.38)) + 0.0000001));
					sin_num = round(trunc(cos(angle) / 0.38) / (abs(trunc(cos(angle) / 0.38)) + 0.0000001));


					if ((gradation.r > Get_Gradation(uv, sin_num[0], cos_num[0]).r) &(gradation.r > Get_Gradation(uv, -sin_num[0], -cos_num[0]).r))
					{
						r = gradation[0];
					}
					else
					{
						r = 0;
					}
					if ((gradation.g > Get_Gradation(uv, sin_num[0], cos_num[0]).g) &(gradation.g > Get_Gradation(uv, -sin_num[0], -cos_num[0]).g))
					{
						g = gradation[0];
					}
					else
					{
						g = 0;
					}
					if ((gradation.b > Get_Gradation(uv, sin_num[0], cos_num[0]).b) &(gradation.b > Get_Gradation(uv, -sin_num[0], -cos_num[0]).b))
					{
						b = gradation[0];
					}
					else
					{
						b = 0;
					}
					//RGBごとに計算して、0.3以上をエッジとする
					r = round(r / 0.3)/0.3;
					g = round(g / 0.3) / 0.3;
					b = round(b / 0.3) / 0.3;
					//平均を撮る
					gr = (r  + g  + b )/3;
					//反転させる
					gr = (1-gr);
					return fixed4(gr, gr, gr, 1);
				}
				fixed4 GrayBitFilter(float2 uv, float2 grabPos)
				{
					fixed4 col;
					int gray_bit;
					int x, y;
					float tmp;
					col = tex2D(_GrabTexture, uv);
					gray_bit = trunc(dot(col.rgb, fixed3(0.299, 0.587, 0.114)) * 32);

					x = uv.x*1000;
					y = uv.y* 700;
					if (gray_bit >= 20)
					{
						return fixed4(1, 1, 1, 1);
					}
					if (gray_bit <= 0)
					{
						return fixed4(0, 0, 0, 1);
					}
					tmp = round(((x + 173 * y) % gray_bit) / (((x + 173 * y) % gray_bit) + 0.0000001));
					return fixed4(tmp, tmp, tmp, 1);
					
				}
				fixed4 frag(v2f i) : SV_Target {
					
					float2 uv = i.grabPos.xy / i.grabPos.w; //0～1に変換 // ★1
					fixed4 graybit;
					fixed4 canny;
					//平均

					//エッジを取得する
					canny = Canny_filter(uv);
					//グレースケールから8Bitっぽい画像を生成する
					graybit = GrayBitFilter(uv, i.grabPos.xy);
					//そのままだと目が痛い白色になるので、重みをつけて和らげる
					return  canny * graybit*_Weaken_White;
				}

				ENDCG
			}

		}
}