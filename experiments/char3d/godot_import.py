"""Настройка импорта glb в Godot для ретаргета: правит <файл>.glb.import.

    python godot_import.py <проект> character <res://путь.glb> [res://папка_карт]   # персонаж: наш скелет (Mixamo)
    python godot_import.py <проект> library   <res://путь.glb> [res://папка_карт]   # библиотека анимаций UAL (Rigify)
Папка карт костей по умолчанию — res://retarget (стенд godot_test); в игре — res://prototype/retarget.

Обе стороны сводятся к стандартной схеме гуманоида Godot (BoneMap из
tools/make_bonemaps.gd), кости переименовываются, скелет зовётся
%GeneralSkeleton — поэтому любая анимация библиотеки играет на любом
персонаже. fix_silhouette приводит позу покоя к общей: наш персонаж стоит
в А-позе, библиотека — в Т-позе; без этого руки в анимациях уходят на ~45°.
Пути к скелету внутри glb — в SKELETON (их печатает tools/inspect.gd).
После правки Godot переимпортирует файл сам (godot --headless --import).
"""
import re
import sys
from pathlib import Path

SKELETON = {"character": "Armature/Skeleton3D", "library": "Rig/Skeleton3D"}
BONEMAP = {"character": "bonemap_mixamo.tres", "library": "bonemap_ual.tres"}


def subresources(kind, maps):
    return ('_subresources={\n"nodes": {\n'
            f'"PATH:{SKELETON[kind]}": {{\n'
            f'"retarget/bone_map": Resource("{maps}/{BONEMAP[kind]}"),\n'
            '"retarget/bone_renamer/rename_bones": true,\n'
            '"retarget/bone_renamer/unique_node/make_unique": true,\n'
            '"retarget/bone_renamer/unique_node/skeleton_name": "GeneralSkeleton",\n'
            '"retarget/rest_fixer/fix_silhouette/enable": true\n'
            '}\n}\n}')


def main(project, kind, res_path, maps="res://retarget"):
    f = Path(project) / (res_path.replace("res://", "") + ".import")
    s = f.read_text(encoding="utf-8")
    s = re.sub(r"_subresources=\{.*?\n\}(?=\n[a-z_/]+=|\Z)|_subresources=\{\}", subresources(kind, maps), s, flags=re.S)
    if kind == "character":
        # LOD и тени-заменители на 1500 треугольниках только портят PS1-вид
        s = s.replace("meshes/generate_lods=true", "meshes/generate_lods=false")
        s = s.replace("meshes/create_shadow_meshes=true", "meshes/create_shadow_meshes=false")
    else:
        s = s.replace('importer="scene"', 'importer="animation_library"').replace('type="PackedScene"', 'type="AnimationLibrary"')
        # путь импортированного файла пересчитает сам Godot (у библиотеки другое расширение)
        s = re.sub(r'^path=".*"\n', "", s, flags=re.M)
        s = re.sub(r"^dest_files=.*\n", "", s, flags=re.M)
    f.write_text(s, encoding="utf-8")
    print(f"{f.name}: {kind}, скелет {SKELETON[kind]}, карта {maps}/{BONEMAP[kind]}")


if __name__ == "__main__":
    main(*sys.argv[1:])
