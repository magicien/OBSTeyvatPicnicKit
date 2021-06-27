local obs = obslua
local bit = require("bit")

----------------
--    共通    --
----------------
function script_description()
  return 'テイワットおでかけセット'
end

function set_render_size(filter)
    local target = obs.obs_filter_get_target(filter.context)

    local width, height
    if target == nil then
        width = 0
        height = 0
    else
        width = obs.obs_source_get_base_width(target)
        height = obs.obs_source_get_base_height(target)
    end

    filter.width = width
    filter.height = height
    if filter.pixel_size ~= nil then
      width = width == 0 and 1 or width
      height = height == 0 and 1 or height
      filter.pixel_size.x = 1.0 / width
      filter.pixel_size.y = 1.0 / height
    end
end

function get_width(filter)
  return filter.width
end

function get_height(filter)
  return filter.height
end

function destroy(filter)
    if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
    end
end

-------------------------
--    1. 明るさ調整    --
-------------------------
local BRIGHTNESS_SETTING_BRIGHTNESS = 'brightness'
local BRIGHTNESS_SETTING_BLUE = 'blue'
local BRIGHTNESS_SETTING_RED = 'red'
local BRIGHTNESS_SETTING_YELLOW = 'yellow'
local BRIGHTNESS_TEXT_BRIGHTNESS = '明るさ'
local BRIGHTNESS_TEXT_BLUE = '青っぽさ（夜）'
local BRIGHTNESS_TEXT_RED = '赤っぽさ（昼〜夕方）'
local BRIGHTNESS_TEXT_YELLOW = '黄色っぽさ（教会等）'

local BRIGHTNESS_SHADER = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float gamma;
uniform float contrast;
uniform float blue;
uniform float red;
uniform float yellow;

sampler_state textureSampler {
    Filter    = Linear;
    AddressU  = Clamp;
    AddressV  = Clamp;
};

struct VertDataIn {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

struct VertDataOut {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

VertDataOut VShader(VertDataIn v_in)
{
    VertDataOut vert_out;
    vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    vert_out.uv  = v_in.uv;
    return vert_out;
}

float4 PShader(VertDataOut v_in) : TARGET
{
    float4 color = image.Sample(textureSampler, v_in.uv);
    float c = (1 - contrast) / 2;
    float3 rgb = pow(color.rgb, float3(gamma, gamma, gamma)) * contrast + float3(c, c, c);
    rgb = float3(rgb.r * (1.0 - blue), rgb.g * (1.0 - blue) * (1.0 - red), rgb.b * (1.0 - red) * (1.0 - yellow));

    return float4(rgb, color.a);
}

technique Draw
{
    pass
    {
        vertex_shader = VShader(v_in);
        pixel_shader  = PShader(v_in);
    }
}
]]

local brightness_source_def = {}
brightness_source_def.id = 'teyvat-brightness'
brightness_source_def.type = obs.OBS_SOURCE_TYPE_FILTER
brightness_source_def.output_flags = obs.OBS_SOURCE_VIDEO
brightness_source_def.get_name = function()
    return "原神：1．明るさ調整"
end

brightness_source_def.create = function(settings, source)
    local filter = {}
    filter.params = {}
    filter.context = source
    filter.pixel_size = obs.vec2()

    set_render_size(filter)

    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(BRIGHTNESS_SHADER, nil, nil)
    if filter.effect ~= nil then
        filter.params.gamma = obs.gs_effect_get_param_by_name(filter.effect, 'gamma')
        filter.params.contrast = obs.gs_effect_get_param_by_name(filter.effect, 'contrast')
        filter.params.blue = obs.gs_effect_get_param_by_name(filter.effect, 'blue')
        filter.params.red = obs.gs_effect_get_param_by_name(filter.effect, 'red')
        filter.params.yellow = obs.gs_effect_get_param_by_name(filter.effect, 'yellow')
    end
    obs.obs_leave_graphics()
    
    if filter.effect == nil then
        brightness_source_def.destroy(filter)
        return nil
    end

    brightness_source_def.update(filter, settings)
    return filter
end

brightness_source_def.destroy = destroy
brightness_source_def.get_width = get_width
brightness_source_def.get_height = get_height

brightness_source_def.update = function(filter, settings)
    local b = obs.obs_data_get_double(settings, BRIGHTNESS_SETTING_BRIGHTNESS)
    if b < 0 then
      filter.gamma = -b + 1
    else
      filter.gamma = 1 / (b + 1)
    end
    filter.contrast = b + 1;

    filter.blue = obs.obs_data_get_double(settings, BRIGHTNESS_SETTING_BLUE)
    filter.red = obs.obs_data_get_double(settings, BRIGHTNESS_SETTING_RED)
    filter.yellow = obs.obs_data_get_double(settings, BRIGHTNESS_SETTING_YELLOW)

    set_render_size(filter)
end

brightness_source_def.video_render = function(filter, effect)
    obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

    obs.gs_effect_set_float(filter.params.gamma, filter.gamma)
    obs.gs_effect_set_float(filter.params.contrast, filter.contrast)
    obs.gs_effect_set_float(filter.params.blue, filter.blue)
    obs.gs_effect_set_float(filter.params.red, filter.red)
    obs.gs_effect_set_float(filter.params.yellow, filter.yellow)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

brightness_source_def.get_properties = function(settings)
    props = obs.obs_properties_create()

    obs.obs_properties_add_float_slider(props, BRIGHTNESS_SETTING_BRIGHTNESS, BRIGHTNESS_TEXT_BRIGHTNESS, -1, 1, 0.01)
    obs.obs_properties_add_float_slider(props, BRIGHTNESS_SETTING_BLUE, BRIGHTNESS_TEXT_BLUE, 0, 1, 0.01)
    obs.obs_properties_add_float_slider(props, BRIGHTNESS_SETTING_RED, BRIGHTNESS_TEXT_RED, 0, 1, 0.01)
    obs.obs_properties_add_float_slider(props, BRIGHTNESS_SETTING_YELLOW, BRIGHTNESS_TEXT_YELLOW, 0, 1, 0.01)

    return props
end

brightness_source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, BRIGHTNESS_SETTING_BRIGHTNESS, 0.0)
    obs.obs_data_set_default_double(settings, BRIGHTNESS_SETTING_BLUE, 0.0)
    obs.obs_data_set_default_double(settings, BRIGHTNESS_SETTING_RED, 0.0)
    obs.obs_data_set_default_double(settings, BRIGHTNESS_SETTING_YELLOW, 0.0)
end

brightness_source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

obs.obs_register_source(brightness_source_def)

---------------------
--    2. 縁取り    --
---------------------
local OUTLINE_SETTING_ALPHA_THRESHOLD = 'alpha_threshold'
local OUTLINE_SETTING_LINE_COLOR = 'line_color'
local OUTLINE_SETTING_LINE_ALPHA = 'line_alpha'
local OUTLINE_SETTING_LINE_WIDTH = 'line_width'
local OUTLINE_TEXT_ALPHA_THRESHOLD = '透明度閾値'
local OUTLINE_TEXT_LINE_COLOR = '線の色'
local OUTLINE_TEXT_LINE_ALPHA = '線の不透明度'
local OUTLINE_TEXT_LINE_WIDTH = '線の幅'

local OUTLINE_SHADER = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float2 pixel_size;
uniform float alpha_threshold;
uniform float4 line_color;
uniform float line_width;

sampler_state textureSampler {
    Filter    = Linear;
    AddressU  = Clamp;
    AddressV  = Clamp;
};

struct VertDataIn {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

struct VertDataOut {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

VertDataOut VShader(VertDataIn v_in)
{
    VertDataOut vert_out;
    vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    vert_out.uv  = v_in.uv;
    return vert_out;
}

float diff(float2 uv, float2 diff)
{
    float4 col1 = image.Sample(textureSampler, uv - diff);
    float4 col2 = image.Sample(textureSampler, uv + diff);

    return col2.a - col1.a;
}

float4 mixColor(float4 src, float4 dst)
{
    return dst * (1.0 - src.a) + float4(src.rgb * src.a, src.a);
}

float4 PShader(VertDataOut v_in) : TARGET
{
    float w = pixel_size.x * line_width / 2;
    float h = pixel_size.y * line_width / 2;

    float d1 = diff(v_in.uv, float2(w, 0));
    float d2 = diff(v_in.uv, float2(0, h));
    float d3 = diff(v_in.uv, float2(w * 0.71, h * 0.71));
    float d4 = diff(v_in.uv, float2(w * 0.71, -h * 0.71));

    float4 color = image.Sample(textureSampler, v_in.uv);

    return (abs(d1) > alpha_threshold
      || abs(d2) > alpha_threshold
      || abs(d3) > alpha_threshold
      || abs(d4) > alpha_threshold)
      ? mixColor(line_color, color)
      : color;
}

technique Draw
{
    pass
    {
        vertex_shader = VShader(v_in);
        pixel_shader  = PShader(v_in);
    }
}
]]

local outline_source_def = {}
outline_source_def.id = 'teyvat-draw-outline'
outline_source_def.type = obs.OBS_SOURCE_TYPE_FILTER
outline_source_def.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO)
outline_source_def.get_name = function()
    return '原神：2．縁取り'
end

outline_source_def.create = function(settings, source)
    local filter = {}
    filter.params = {}
    filter.context = source
    filter.pixel_size = obs.vec2()
    filter.line_color = obs.vec4()

    set_render_size(filter)

    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(OUTLINE_SHADER, nil, nil)
    if filter.effect ~= nil then
        filter.params.pixel_size = obs.gs_effect_get_param_by_name(filter.effect, 'pixel_size')
        filter.params.alpha_threshold = obs.gs_effect_get_param_by_name(filter.effect, 'alpha_threshold')
        filter.params.line_color = obs.gs_effect_get_param_by_name(filter.effect, 'line_color')
        filter.params.line_alpha = obs.gs_effect_get_param_by_name(filter.effect, 'line_alpha')
        filter.params.line_width = obs.gs_effect_get_param_by_name(filter.effect, 'line_width')
    end
    obs.obs_leave_graphics()
    
    if filter.effect == nil then
        outline_source_def.destroy(filter)
        return nil
    end

    outline_source_def.update(filter, settings)
    return filter
end

outline_source_def.destroy = destroy
outline_source_def.get_width = get_width
outline_source_def.get_height = get_height

outline_source_def.update = function(filter, settings)
    filter.alpha_threshold = obs.obs_data_get_double(settings, OUTLINE_SETTING_ALPHA_THRESHOLD)

    line_color = obs.obs_data_get_int(settings, OUTLINE_SETTING_LINE_COLOR)
    line_alpha = math.floor(obs.obs_data_get_double(settings, OUTLINE_SETTING_LINE_ALPHA) * 255)
    obs.vec4_from_rgba(filter.line_color, line_color + line_alpha * 0x1000000)
    if line_alpha <= 0 then
      filter.line_color.w = 0
    end
    filter.line_width = obs.obs_data_get_double(settings, OUTLINE_SETTING_LINE_WIDTH)

    set_render_size(filter)
end

outline_source_def.video_render = function(filter, effect)
    obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

    obs.gs_effect_set_vec2(filter.params.pixel_size, filter.pixel_size)
    obs.gs_effect_set_float(filter.params.alpha_threshold, filter.alpha_threshold)
    obs.gs_effect_set_vec4(filter.params.line_color, filter.line_color)
    obs.gs_effect_set_float(filter.params.line_width, filter.line_width)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

outline_source_def.get_properties = function(settings)
    props = obs.obs_properties_create()

    obs.obs_properties_add_float_slider(props, OUTLINE_SETTING_ALPHA_THRESHOLD, OUTLINE_TEXT_ALPHA_THRESHOLD, 0, 1, 0.01)
    obs.obs_properties_add_color(props, OUTLINE_SETTING_LINE_COLOR, OUTLINE_TEXT_LINE_COLOR)
    obs.obs_properties_add_float_slider(props, OUTLINE_SETTING_LINE_ALPHA, OUTLINE_TEXT_LINE_ALPHA, 0, 1, 0.01)
    obs.obs_properties_add_float_slider(props, OUTLINE_SETTING_LINE_WIDTH, OUTLINE_TEXT_LINE_WIDTH, 0, 100, 0.1)

    return props
end

outline_source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, OUTLINE_SETTING_ALPHA_THRESHOLD, 0.99)
    obs.obs_data_set_default_int(settings, OUTLINE_SETTING_LINE_COLOR, 0x000000)
    obs.obs_data_set_default_double(settings, OUTLINE_SETTING_LINE_ALPHA, 1)
    obs.obs_data_set_default_double(settings, OUTLINE_SETTING_LINE_WIDTH, 1)
end

outline_source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

obs.obs_register_source(outline_source_def)

-----------------------
--    3. ブルーム    --
-----------------------
local BLOOM_SETTING_BLOOM_SIZE = 'bloom_size'
local BLOOM_SETTING_BLOOM_ALPHA = 'bloom_alpha'
local BLOOM_SETTING_BRIGHTNESS_THRESHOLD = 'brightness_threshold'
local BLOOM_TEXT_BLOOM_SIZE = '光の大きさ'
local BLOOM_TEXT_BLOOM_ALPHA = '適用率'
local BLOOM_TEXT_BRIGHTNESS_THRESHOLD = '明るさ閾値'

local BLOOM_SHADER = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float2 pixel_size;
uniform float bloom_size;
uniform float bloom_alpha;
uniform float brightness_threshold;

sampler_state textureSampler {
    Filter    = Linear;
    AddressU  = Clamp;
    AddressV  = Clamp;
};

struct VertDataIn {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

struct VertDataOut {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

VertDataOut VShader(VertDataIn v_in)
{
    VertDataOut vert_out;
    vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    vert_out.uv  = v_in.uv;
    return vert_out;
}

float4 PShader(VertDataOut v_in) : TARGET
{
    int num_sample = 2;
    float4 result = float4(0, 0, 0, 0);
    float4 color = float4(0, 0, 0, 0);
    float brightness = 0;

    for (int i=-num_sample; i<=num_sample; ++i) {
      for (int j=-num_sample; j<=num_sample; ++j) {
        color = image.Sample(textureSampler, v_in.uv + float2(pixel_size.x * i, pixel_size.y * j) * bloom_size);
        brightness = max(color.r, max(color.g, color.b));

        result += brightness > brightness_threshold ? color : float4(0, 0, 0, 0);
      }
    }
    result /= pow(num_sample + 1, 2);
    result.a *= bloom_alpha;

    float4 baseColor = image.Sample(textureSampler, v_in.uv);

    return baseColor + float4(result.rgb * result.a, result.a);
}

technique Draw
{
    pass
    {
        vertex_shader = VShader(v_in);
        pixel_shader  = PShader(v_in);
    }
}
]]

local bloom_source_def = {}
bloom_source_def.id = 'teyvat-bloom'
bloom_source_def.type = obs.OBS_SOURCE_TYPE_FILTER
bloom_source_def.output_flags = obs.OBS_SOURCE_VIDEO
bloom_source_def.get_name = function()
    return "原神：3．ブルーム"
end

bloom_source_def.create = function(settings, source)
    local filter = {}
    filter.params = {}
    filter.context = source
    filter.pixel_size = obs.vec2()

    set_render_size(filter)

    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(BLOOM_SHADER, nil, nil)
    if filter.effect ~= nil then
        filter.params.pixel_size = obs.gs_effect_get_param_by_name(filter.effect, 'pixel_size')
        filter.params.bloom_alpha = obs.gs_effect_get_param_by_name(filter.effect, 'bloom_alpha')
        filter.params.bloom_size = obs.gs_effect_get_param_by_name(filter.effect, 'bloom_size')
        filter.params.brightness_threshold = obs.gs_effect_get_param_by_name(filter.effect, 'brightness_threshold')
    end
    obs.obs_leave_graphics()
    
    if filter.effect == nil then
        bloom_source_def.destroy(filter)
        return nil
    end

    bloom_source_def.update(filter, settings)
    return filter
end

bloom_source_def.destroy = destroy
bloom_source_def.get_width = get_width
bloom_source_def.get_height = get_height

bloom_source_def.update = function(filter, settings)
    filter.bloom_alpha = obs.obs_data_get_double(settings, BLOOM_SETTING_BLOOM_ALPHA) * 0.1
    filter.bloom_size = obs.obs_data_get_double(settings, BLOOM_SETTING_BLOOM_SIZE)
    filter.brightness_threshold = obs.obs_data_get_double(settings, BLOOM_SETTING_BRIGHTNESS_THRESHOLD)

    set_render_size(filter)
end

bloom_source_def.video_render = function(filter, effect)
    obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

    obs.gs_effect_set_vec2(filter.params.pixel_size, filter.pixel_size)
    obs.gs_effect_set_float(filter.params.brightness_threshold, filter.brightness_threshold)
    obs.gs_effect_set_float(filter.params.bloom_alpha, filter.bloom_alpha)
    obs.gs_effect_set_float(filter.params.bloom_size, filter.bloom_size)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

bloom_source_def.get_properties = function(settings)
    props = obs.obs_properties_create()

    obs.obs_properties_add_float_slider(props, BLOOM_SETTING_BRIGHTNESS_THRESHOLD, BLOOM_TEXT_BRIGHTNESS_THRESHOLD, 0, 1, 0.01);
    obs.obs_properties_add_float_slider(props, BLOOM_SETTING_BLOOM_SIZE, BLOOM_TEXT_BLOOM_SIZE, 0, 10, 0.1);
    obs.obs_properties_add_float_slider(props, BLOOM_SETTING_BLOOM_ALPHA, BLOOM_TEXT_BLOOM_ALPHA, 0, 1, 0.01);

    return props
end

bloom_source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, BLOOM_SETTING_BRIGHTNESS_THRESHOLD, 0.90);
    obs.obs_data_set_default_double(settings, BLOOM_SETTING_BLOOM_SIZE, 4.0);
    obs.obs_data_set_default_double(settings, BLOOM_SETTING_BLOOM_ALPHA, 0.2);
end

bloom_source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

obs.obs_register_source(bloom_source_def)

-------------------------------
--    4. 鏡面反射（合成）    --
-------------------------------
local REFLECTION_COMP_SETTING_Y_POS = 'y_pos'
local REFLECTION_COMP_SETTING_BLUR = 'blur'
local REFLECTION_COMP_SETTING_ALPHA = 'alpha'
local REFLECTION_COMP_SETTING_VIEW_TOP = 'view_top'
local REFLECTION_COMP_SETTING_VIEW_BOTTOM = 'view_bottom'
local REFLECTION_COMP_TEXT_Y_POS = '反射の位置'
local REFLECTION_COMP_TEXT_BLUR = 'ぼかし'
local REFLECTION_COMP_TEXT_ALPHA = '不透明度'
local REFLECTION_COMP_TEXT_VIEW_TOP = '表示範囲（上限）'
local REFLECTION_COMP_TEXT_VIEW_BOTTOM = '表示範囲（下限）'

local REFLECTION_COMP_SHADER = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float2 pixel_size;
uniform float y_pos;
uniform float blur;
uniform float alpha;
uniform float view_top;
uniform float view_bottom;

sampler_state textureSampler {
    Filter      = Linear;
    AddressU    = Border;
    AddressV    = Border;
};

struct VertDataIn {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

struct VertDataOut {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

float4 mixColor(float4 src, float4 dst)
{
    return dst * (1.0 - src.a) + float4(src.rgb * src.a, src.a);
}

VertDataOut VShader(VertDataIn v_in)
{
    VertDataOut vert_out;
    vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    vert_out.uv  = v_in.uv;
    return vert_out;
}

float4 PShader(VertDataOut v_in) : TARGET
{
    float2 uv = float2(v_in.uv.x, 1.0 - v_in.uv.y + y_pos);
    float4 baseColor = image.Sample(textureSampler, v_in.uv);

    int num_sample = 2;
    float4 color = float4(0, 0, 0, 0);
    float4 reflection = float4(0, 0, 0, 0);
    float2 pos = float2(0, 0);
    for (int i=-num_sample; i<=num_sample; ++i) {
      for (int j=-num_sample; j<=num_sample; ++j) {
        pos = uv + float2(pixel_size.x * i, pixel_size.y * j) * blur;
        color = image.Sample(textureSampler, pos);
        reflection += (pos.y >= view_top && pos.y <= view_bottom) ? float4(color.rgb * color.a, color.a) : float4(0, 0, 0, 0);
      }
    }
    reflection = reflection.a == 0 ? float4(0, 0, 0, 0) : float4(reflection.rgb / reflection.a, reflection.a / pow(num_sample + 1, 2) * alpha);

    return mixColor(baseColor, float4(reflection.rgb, reflection.a * alpha));
}

technique Draw
{
    pass
    {
        vertex_shader = VShader(v_in);
        pixel_shader  = PShader(v_in);
    }
}
]]

local reflection_comp_source_def = {}
reflection_comp_source_def.id = 'teyvat-reflection-composit'
reflection_comp_source_def.type = obs.OBS_SOURCE_TYPE_FILTER
reflection_comp_source_def.output_flags = obs.OBS_SOURCE_VIDEO
reflection_comp_source_def.get_name = function()
    return "原神：4．鏡面反射（合成）"
end

reflection_comp_source_def.create = function(settings, source)
    local filter = {}
    filter.params = {}
    filter.context = source
    filter.pixel_size = obs.vec2()

    set_render_size(filter)

    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(REFLECTION_COMP_SHADER, nil, nil)
    if filter.effect ~= nil then
        filter.params.pixel_size = obs.gs_effect_get_param_by_name(filter.effect, 'pixel_size')
        filter.params.y_pos = obs.gs_effect_get_param_by_name(filter.effect, 'y_pos')
        filter.params.blur = obs.gs_effect_get_param_by_name(filter.effect, 'blur')
        filter.params.alpha = obs.gs_effect_get_param_by_name(filter.effect, 'alpha')
        filter.params.view_top = obs.gs_effect_get_param_by_name(filter.effect, 'view_top')
        filter.params.view_bottom = obs.gs_effect_get_param_by_name(filter.effect, 'view_bottom')
    end
    obs.obs_leave_graphics()
    
    if filter.effect == nil then
        reflection_comp_source_def.destroy(filter)
        return nil
    end

    reflection_comp_source_def.update(filter, settings)
    return filter
end

reflection_comp_source_def.destroy = destroy
reflection_comp_source_def.get_width = get_width
reflection_comp_source_def.get_height = get_height

reflection_comp_source_def.update = function(filter, settings)
    filter.y_pos = obs.obs_data_get_double(settings, REFLECTION_COMP_SETTING_Y_POS)
    filter.blur = obs.obs_data_get_double(settings, REFLECTION_COMP_SETTING_BLUR)
    filter.alpha = obs.obs_data_get_double(settings, REFLECTION_COMP_SETTING_ALPHA)
    filter.view_top = obs.obs_data_get_double(settings, REFLECTION_COMP_SETTING_VIEW_TOP)
    filter.view_bottom = obs.obs_data_get_double(settings, REFLECTION_COMP_SETTING_VIEW_BOTTOM)

    set_render_size(filter)
end

reflection_comp_source_def.video_render = function(filter, effect)
    obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

    obs.gs_effect_set_vec2(filter.params.pixel_size, filter.pixel_size)
    obs.gs_effect_set_float(filter.params.y_pos, filter.y_pos)
    obs.gs_effect_set_float(filter.params.blur, filter.blur)
    obs.gs_effect_set_float(filter.params.alpha, filter.alpha)
    obs.gs_effect_set_float(filter.params.view_top, filter.view_top)
    obs.gs_effect_set_float(filter.params.view_bottom, filter.view_bottom)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

reflection_comp_source_def.get_properties = function(settings)
    props = obs.obs_properties_create()

    obs.obs_properties_add_float_slider(props, REFLECTION_COMP_SETTING_Y_POS, REFLECTION_COMP_TEXT_Y_POS, 0, 1, 0.01);
    obs.obs_properties_add_float_slider(props, REFLECTION_COMP_SETTING_BLUR, REFLECTION_COMP_TEXT_BLUR, 0, 100, 0.1);
    obs.obs_properties_add_float_slider(props, REFLECTION_COMP_SETTING_ALPHA, REFLECTION_COMP_TEXT_ALPHA, 0, 1, 0.01);
    obs.obs_properties_add_float_slider(props, REFLECTION_COMP_SETTING_VIEW_TOP, REFLECTION_COMP_TEXT_VIEW_TOP, 0, 1, 0.01);
    obs.obs_properties_add_float_slider(props, REFLECTION_COMP_SETTING_VIEW_BOTTOM, REFLECTION_COMP_TEXT_VIEW_BOTTOM, 0, 1, 0.01);

    return props
end

reflection_comp_source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, REFLECTION_COMP_SETTING_Y_POS, 0.80);
    obs.obs_data_set_default_double(settings, REFLECTION_COMP_SETTING_BLUR, 5.0);
    obs.obs_data_set_default_double(settings, REFLECTION_COMP_SETTING_ALPHA, 0.9);
    obs.obs_data_set_default_double(settings, REFLECTION_COMP_SETTING_VIEW_TOP, 0.0);
    obs.obs_data_set_default_double(settings, REFLECTION_COMP_SETTING_VIEW_BOTTOM, 1.0);
end

reflection_comp_source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

obs.obs_register_source(reflection_comp_source_def)

---------------------
--    5. 透明度    --
---------------------
local TRANSPARENT_SETTING_ALPHA = 'dither_alpha'
local TRANSPARENT_SETTING_DOT_SIZE = 'dither_dot_size'
local TRANSPARENT_TEXT_ALPHA = '不透明度'
local TRANSPARENT_TEXT_DOT_SIZE = 'ドットの大きさ'

local TRANSPARENT_SHADER = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float2 mesh_size;
uniform float4x4 dither_mask;

sampler_state textureSampler {
    Filter    = Linear;
    AddressU  = Clamp;
    AddressV  = Clamp;
};

struct VertDataIn {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

struct VertDataOut {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

VertDataOut VShader(VertDataIn v_in)
{
    VertDataOut vert_out;
    vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    vert_out.uv  = v_in.uv;
    return vert_out;
}

float4 PShader(VertDataOut v_in) : TARGET
{
    int dx = int(v_in.uv.x * mesh_size.x) % 4;
    int dy = int(v_in.uv.y * mesh_size.y) % 4;
    float4 color = image.Sample(textureSampler, v_in.uv);

    return float4(color.rgb, color.a * dither_mask[dx][dy]);
}

technique Draw
{
    pass
    {
        vertex_shader = VShader(v_in);
        pixel_shader  = PShader(v_in);
    }
}
]]

local transparent_source_def = {}
transparent_source_def.id = 'teyvat-transparent'
transparent_source_def.type = obs.OBS_SOURCE_TYPE_FILTER
transparent_source_def.output_flags = obs.OBS_SOURCE_VIDEO
transparent_source_def.get_name = function()
    return "原神：5．透過"
end

function set_mesh_size(filter)
    filter.mesh_size.x = filter.width / filter.dither_dot_size
    filter.mesh_size.y = filter.height / filter.dither_dot_size
end

function set_dither_mask(filter)
    filter.dither_mask.x.x = filter.alpha >= 1.0 / 16.0 and 1 or 0
    filter.dither_mask.x.y = filter.alpha >= 13.0 / 16.0 and 1 or 0
    filter.dither_mask.x.z = filter.alpha >= 4.0 / 16.0 and 1 or 0
    filter.dither_mask.x.w = filter.alpha >= 16.0 / 16.0 and 1 or 0
    filter.dither_mask.y.x = filter.alpha >= 9.0 / 16.0 and 1 or 0
    filter.dither_mask.y.y = filter.alpha >= 5.0 / 16.0 and 1 or 0
    filter.dither_mask.y.z = filter.alpha >= 12.0 / 16.0 and 1 or 0
    filter.dither_mask.y.w = filter.alpha >= 8.0 / 16.0 and 1 or 0
    filter.dither_mask.z.x = filter.alpha >= 3.0 / 16.0 and 1 or 0
    filter.dither_mask.z.y = filter.alpha >= 15.0 / 16.0 and 1 or 0
    filter.dither_mask.z.z = filter.alpha >= 2.0 / 16.0 and 1 or 0
    filter.dither_mask.z.w = filter.alpha >= 14.0 / 16.0 and 1 or 0
    filter.dither_mask.t.x = filter.alpha >= 11.0 / 16.0 and 1 or 0
    filter.dither_mask.t.y = filter.alpha >= 7.0 / 16.0 and 1 or 0
    filter.dither_mask.t.z = filter.alpha >= 10.0 / 16.0 and 1 or 0
    filter.dither_mask.t.w = filter.alpha >= 6.0 / 16.0 and 1 or 0
end

transparent_source_def.create = function(settings, source)
    local filter = {}
    filter.params = {}
    filter.context = source

    filter.mesh_size = obs.vec2()
    filter.dither_mask = obs.matrix4()
    filter.alpha = 1.0
    filter.dither_dot_size = 1.0

    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(TRANSPARENT_SHADER, nil, nil)
    if filter.effect ~= nil then
        filter.params.mesh_size = obs.gs_effect_get_param_by_name(filter.effect, 'mesh_size')
        filter.params.dither_mask = obs.gs_effect_get_param_by_name(filter.effect, 'dither_mask')
    end
    obs.obs_leave_graphics()
    
    if filter.effect == nil then
        transparent_source_def.destroy(filter)
        return nil
    end

    set_render_size(filter)
    set_mesh_size(filter)
    set_dither_mask(filter)

    transparent_source_def.update(filter, settings)
    return filter
end

transparent_source_def.destroy = destroy
transparent_source_def.get_width = get_width
transparent_source_def.get_height = get_height

transparent_source_def.update = function(filter, settings)
    set_render_size(filter)
    set_mesh_size(filter)

    filter.alpha = obs.obs_data_get_double(settings, TRANSPARENT_SETTING_ALPHA)
    filter.dither_dot_size = obs.obs_data_get_double(settings, TRANSPARENT_SETTING_DOT_SIZE)
    set_dither_mask(filter)
end

transparent_source_def.video_render = function(filter, effect)
    obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

    obs.gs_effect_set_vec2(filter.params.mesh_size, filter.mesh_size)
    obs.gs_effect_set_matrix4(filter.params.dither_mask, filter.dither_mask)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

transparent_source_def.get_properties = function(settings)
    props = obs.obs_properties_create()

    obs.obs_properties_add_float_slider(props, TRANSPARENT_SETTING_ALPHA, TRANSPARENT_TEXT_ALPHA, 0, 1, 0.01)
    obs.obs_properties_add_float_slider(props, TRANSPARENT_SETTING_DOT_SIZE, TRANSPARENT_TEXT_DOT_SIZE, 0.1, 10, 0.1)

    return props
end

transparent_source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, TRANSPARENT_SETTING_ALPHA, 1.0);
    obs.obs_data_set_default_double(settings, TRANSPARENT_SETTING_DOT_SIZE, 1.0);
end

transparent_source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
    set_mesh_size(filter)
end

obs.obs_register_source(transparent_source_def)

----------------------------
--    鏡面反射（単独）    --
----------------------------
local REFLECTION_SETTING_BLUR = 'blur'
local REFLECTION_SETTING_ALPHA = 'alpha'
local REFLECTION_TEXT_BLUR = 'ぼかし'
local REFLECTION_TEXT_ALPHA = '不透明度'

local REFLECTION_SHADER = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float2 pixel_size;
uniform float blur;
uniform float alpha;

sampler_state textureSampler {
    Filter    = Linear;
    AddressU  = Clamp;
    AddressV  = Clamp;
};

struct VertDataIn {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

struct VertDataOut {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

float4 mixColor(float4 src, float4 dst)
{
    return dst * (1.0 - src.a) + float4(src.rgb * src.a, src.a);
}

VertDataOut VShader(VertDataIn v_in)
{
    VertDataOut vert_out;
    vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    vert_out.uv  = v_in.uv;
    return vert_out;
}

float4 PShader(VertDataOut v_in) : TARGET
{
    int num_sample = 3;
    float2 uv = float2(v_in.uv.x, 1.0 - v_in.uv.y);
    float4 result = float4(0, 0, 0, 0);
    float4 color = float4(0, 0, 0, 0);

    for (int i=-num_sample; i<=num_sample; ++i) {
      for (int j=-num_sample; j<=num_sample; ++j) {
        color = image.Sample(textureSampler, uv + float2(pixel_size.x * i, pixel_size.y * j) * blur);
        result += float4(color.rgb * color.a, color.a);
      }
    }
    result = float4(result.rgb / result.a, result.a / pow(num_sample + 1, 2) * alpha);

    return result;
}

technique Draw
{
    pass
    {
        vertex_shader = VShader(v_in);
        pixel_shader  = PShader(v_in);
    }
}
]]

local reflection_source_def = {}
reflection_source_def.id = 'teyvat-specular-reflection'
reflection_source_def.type = obs.OBS_SOURCE_TYPE_FILTER
reflection_source_def.output_flags = obs.OBS_SOURCE_VIDEO
reflection_source_def.get_name = function()
    return "原神：鏡面反射（単独）"
end

reflection_source_def.create = function(settings, source)
    local filter = {}
    filter.params = {}
    filter.context = source
    filter.pixel_size = obs.vec2()

    set_render_size(filter)

    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(REFLECTION_SHADER, nil, nil)
    if filter.effect ~= nil then
        filter.params.pixel_size = obs.gs_effect_get_param_by_name(filter.effect, 'pixel_size')
        filter.params.blur = obs.gs_effect_get_param_by_name(filter.effect, 'blur')
        filter.params.alpha = obs.gs_effect_get_param_by_name(filter.effect, 'alpha')
    end
    obs.obs_leave_graphics()
    
    if filter.effect == nil then
        reflection_source_def.destroy(filter)
        return nil
    end

    reflection_source_def.update(filter, settings)
    return filter
end

reflection_source_def.destroy = destroy
reflection_source_def.get_width = get_width
reflection_source_def.get_height = get_height

reflection_source_def.update = function(filter, settings)
    filter.blur = obs.obs_data_get_double(settings, REFLECTION_SETTING_BLUR)
    filter.alpha = obs.obs_data_get_double(settings, REFLECTION_SETTING_ALPHA)

    set_render_size(filter)
end

reflection_source_def.video_render = function(filter, effect)
    obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

    obs.gs_effect_set_vec2(filter.params.pixel_size, filter.pixel_size)
    obs.gs_effect_set_float(filter.params.blur, filter.blur)
    obs.gs_effect_set_float(filter.params.alpha, filter.alpha)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

reflection_source_def.get_properties = function(settings)
    props = obs.obs_properties_create()

    obs.obs_properties_add_float_slider(props, REFLECTION_SETTING_BLUR, REFLECTION_TEXT_BLUR, 0, 100, 0.1);
    obs.obs_properties_add_float_slider(props, REFLECTION_SETTING_ALPHA, REFLECTION_TEXT_ALPHA, 0, 1, 0.01);

    return props
end

reflection_source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, REFLECTION_SETTING_BLUR, 5.0);
    obs.obs_data_set_default_double(settings, REFLECTION_SETTING_ALPHA, 0.9);
end

reflection_source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

obs.obs_register_source(reflection_source_def)

